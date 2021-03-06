%**************************************************************************
%To accompany Knittel and Metaxoglou (2008)
% Estimation of Random Coefficient Demand Models: 
% Challenges, Difficulties and Warnings
%Knittel      : crknittel@ucdavis.edu
%Metaxoglou   : konstantinos.metaxoglou@bateswhite.com
%**************************************************************************

clear all
close all
close hidden
warning off all
clc

%**************************************************************************
%Define globals
%**************************************************************************
global invA ns x1 x2 v demogr s_jt IV vfull dfull...
    theta1 theti thetj cdid cdindex optrout...
    mymaxfunevals mvalold...
    oldt2 gmmresid mvalolds mvalold0 mvalold00 mvalolds2...
    fvals_track fcnevals ppp mval_track

% *************************************************************************
% Define paths for codes, optimization results and logs
% *************************************************************************
code_path    =pwd;
results_path =[code_path,'\optimization results\'];
logs_path    =[code_path,'\optimization logs\'];
add_path     =[code_path,'\optimization routines\'];
addpath(add_path);

% *************************************************************************
% Loop over optimization routines
% *************************************************************************
for optrout=6:6

    mytolx=1e-3;
    mytolfun=1e-3;
    mymaxiters=5*10^5;
    mymaxfunevals=400;
    perturbs=(1:1:1)';
    
    fvals_track=NaN*ones(mymaxfunevals,size(perturbs,1));

    if optrout==1,  perturbs=perturbs(perturbs~=6,:);
        perturbs=perturbs(perturbs~=39,:);
        perturbs=perturbs(perturbs~=22,:);
    end
    if optrout==2,  perturbs=perturbs(perturbs~=6,:);
        perturbs=perturbs(perturbs~=28,:);
        perturbs=perturbs(perturbs~=36,:);
    end

    if optrout<=9
        outfile=[logs_path,['nevo_0',num2str(optrout),'_optim_log.txt']];
        matfile=['nevo_0',num2str(optrout),'_data_optim.mat'];
    else
        outfile=[logs_path,['nevo_',num2str(optrout),'_optim_log.txt']];
        matfile=['nevo_',num2str(optrout),'_data_optim.mat'];
    end

    % *********************************************************************
    % Initialize log files and matrices containing various results
    % *********************************************************************
    fid        =fopen(outfile,'w'); fclose(fid);
    counts2    =[];                  %store function evaluations
    deltas     =[];                  %store deltas
    exit_infos =[];                  %store exit info
    fvals      =[];                  %store GMM values
    gmmresids  =[];                  %store gmm residuals
    gradients  =[];                  %store analytical gradients
    gradients2 =[];                  %store numerical  gradients I
    gradients3 =[];                  %store numerical  gradients II   
    hessians   =[];                  %store hessians
    hessians2  =[];                  %store hessians II    
    mvalolds2  =[];                  %store mvalolds
    perturbs2  =[];                  %store perturbation set number
    std_errors =[];                  %store std.errors
    theta1s    =[];                  %store theta1s
    theta2s    =[];                  %store theta2s
    fvals_track=[];                  %store GMM values in all evaluations
    tocs       =[];                  %store time of completion
    
    % *********************************************************************
    % Load data
    % *********************************************************************

    load ps2
    load iv
    IV = [iv(:,2:21) x1(:,2:25)];
    clear iv

    ns   = 20;
    nmkt = 94;
    nbrn = 24;

    cdid    = kron([1:nmkt]',ones(nbrn,1));
    cdindex = [nbrn:nbrn:nbrn*nmkt]';

    % *********************************************************************
    % Logit IV regression
    % *********************************************************************

    dfull=demogr(cdid,:);
    vfull=v(cdid,:);

    invA = inv([IV'*IV]);

    temp = cumsum(s_jt);
    sum1 = temp(cdindex,:);
    sum1(2:size(sum1,1),:) = diff(sum1);
    outshr = 1.0 - sum1(cdid,:);

    y = log(s_jt) - log(outshr);
    mid = x1'*IV*invA*IV';
    t = inv(mid*x1)*mid*y;
    mvalold_logit = x1*t;

    n=size(x1,1);
    k=size(x1,2);

    ESS=y'*y-2*t'*x1'*y+t'*x1'*x1*t;
    s2=ESS/(n-k);
    A=(x1'*(IV*inv(IV'*IV)*IV')*x1);
    se=sqrt(diag(s2*inv(A)));

    % *********************************************************************
    % Start optimization routine with perturb_no different starting values
    % for theta2: normrnd(0,1,size(theta2));
    % for delta:  delta_logit+normrnd(0,stddev(delta_logit),2256,1)
    % *********************************************************************
    diary(outfile)

    for ppp=1:size(perturbs,1)
        tic
        perturb=perturbs(ppp,1);
        fprintf('\n');
        fprintf('========================================================================\n')
        fprintf('                       optimization routine :%2i\n',optrout);
        fprintf('                     set of starting values :%2i\n',perturb);
        fprintf('========================================================================\n')        

        %Nevo (JEMS,2000) estimates
        theta2w= [0.377,  3.089,      0,   1.186,       0;
                  1.848, 16.598, -0.659,       0,  11.625;
                  0.004, -0.193,      0,   0.029,       0;
                  0.081,  1.468,      0,  -1.514,       0];

        [theti, thetj, theta2]=find(theta2w);
        randn('state',1000*perturb);
        theta2=normrnd(0,1,size(theta2));
        theta2w0= full(sparse(theti,thetj,theta2));

        randn('state',1000*perturb);

        mvalold=mvalold_logit+normrnd(0,sqrt(s2),size(x1,1),1);
        
        %initialize matrix tracking deltas
        mval_track=[mvalold_logit];

        mvalold=exp(mvalold);
        oldt2 = zeros(size(theta2));

        fprintf('theta2 starting values:\n')        
        printm(theta2');
        
        %initialize counter of function evaluations
        fcnevals=0;
        
        % *****************************************************************
        % Quasi-Newton 1
        % *****************************************************************
        if optrout==1
            options = optimset(...
                'GradObj','on',...
                'HessUpdate','bfgs',...
                'LargeScale','off',...
                'MaxFunEvals',mymaxfunevals,...
                'TolFun',mytolfun,...
                'TolX',mytolx,...
                'MaxIter',mymaxiters,...
                'Display','iter');
            [theta2,fval,exit_info,tmp]=fminunc('gmmobj2',theta2,options);
            counts=tmp.funcCount;
        end

        % *****************************************************************
        % Nelder-Mead Simplex
        % *****************************************************************
        if optrout==2
            options=optimset('TolFun',mytolfun,...
                'TolX',mytolx,...
                'Display','iter',....
                'MaxIter',mymaxiters,...
                'MaxFunEvals',mymaxfunevals);
            [theta2,fval,exit_info,tmp] = fminsearch('gmmobj',theta2,options);
            counts=tmp.funcCount;
        end

        % *****************************************************************
        % Solvopt
        % *****************************************************************
        if optrout==3
            warning('off','MATLAB:dispatcher:InexactMatch');
            options=Soptions;
            options(2)=mytolx;
            options(3)=mytolfun;
            options(4)=mymaxiters;
            options(5)=1;
            [theta2,fval,tmp] = SOLVOPT(theta2,'gmmobj2','gradobj',options);
            exit_info=tmp(9);
            counts=tmp(10);
        end

        % *****************************************************************
        % Conjugate gradient
        % *****************************************************************
        if optrout==4
            opts=[];
            opts(1)=1;
            opts(2)=1;
            opts(3)=1;
            opts(4)=mytolfun;
            opts(5)=mytolx;
            opts(6)=mymaxfunevals;
            opts(7:9)=[1e-4 1e-6 10];
            [theta2,tmp,perf,neval] = conj_grad('gmmobj3',0,theta2,opts);
            theta2=theta2(:,end);
            fval=tmp(1);
            exit_info=tmp(6);
            counts=(neval);
        end

        % *****************************************************************
        % Quasi-Newton 2
        % *****************************************************************
        if optrout==5
            opts=[];
            opts(1)=1;
            opts(2)=mytolfun;
            opts(3)=mytolx;
            opts(4)=mymaxfunevals;
            [theta2, tmp, perf, D,neval] = ucminf('gmmobj3',0,theta2,opts);
            theta2=theta2(:,end);
            fval=tmp(1);
            exit_info=tmp(6);
            counts=(neval);
        end

        % *****************************************************************
        % GA-JBES
        % *****************************************************************
        if optrout==6;
            uu=-10^4*ones(size(theta2));
            vv=10^4*ones(size(theta2));
            parspace=[uu,vv];
            [ga_out,ga_beta,ga_funeval]=gamin('gmmobj',parspace,theta2);
            theta2=ga_beta;
            fval=ga_out(3);
            exit_info=1;
            counts=ga_funeval;
        end;

        % *****************************************************************
        % Simulated annealing
        % *****************************************************************
        if optrout==7
            neps = 4;           
            eps = 1.0E-4;
            rt = .9;
            seed = perturb*1000;
            ns = 20;
            nt = 5;
            maxevl = mymaxfunevals;
            iprint = 2;
            npar = size(theta2,1);
            lb = theta2-10*theta2;
            ub = theta2+10*theta2;
            c  = 2.0*ones(npar,1);
            t = 5.0;
            vm = 1.0*ones(npar,1);
            randn('state',seed);
            rand('state',seed);
            fprintf('-------------------------------------------------\n');
            fprintf('              Simulated Annealing parameters     \n');
            fprintf('-------------------------------------------------\n');
            fprintf('number of parameters                   : %8.i\n',npar);
            fprintf('Temperature                            : %8.4f\n',t);
            fprintf('Temperature reduction factror          : %8.4f\n',rt);
            fprintf('epsilon                                : %8.4f\n',eps);
            fprintf('Iterations for the step to be adjusted : %8i\n',ns);
            fprintf('Iterations before reducing temperature : %8i\n',nt);
            fprintf('Number of last iterations              : %8i\n',neps);
            fprintf('Max number of function evaluations     : %8i\n',maxevl);
            fprintf('Options for output printing            : %8i\n',iprint);
            fprintf('Random generator Seed                  : %8i\n',seed);
            disp('-------------------------------------------------');            
            [est, fval, nacc, nfcnev, nobds, ier, t, vm] =sim_anneal('gmmobj',...
                theta2,0,rt,eps,ns,nt,neps,maxevl,lb,ub,c,iprint,t,vm);
            theta2=est;
            exit_info=1;
            fval=abs(fval);
            counts=nfcnev;
        end

        % *****************************************************************
        % MADS
        % *****************************************************************
        if optrout==8
            options=psoptimset('Cache','on',...
                'CompletePoll','off',...
                'CompleteSearch','off',...
                'Display','iter',...
                'MaxFunevals',mymaxfunevals,...
                'MaxIter',mymaxiters,...
                'SearchMethod','MADSPositiveBasisNp1',...
                'PollMethod','MADSPositiveBasis2N',...
                'TolFun',mytolfun,...
                'TolX',mytolx,...
                'PlotFcn',[]);
            [theta2, fval, exit_info, tmp] =...
                patternsearch(@gmmobj,theta2,[],[],[],[],[],[],options);
                counts=tmp.funccount;
        end

        % *****************************************************************
        % GPS 
        % *****************************************************************
        if optrout==9
            options=psoptimset('Cache','on',...
                'CompletePoll','off',...
                'CompleteSearch','off',...
                'Display','iter',...
                'MaxFunevals',mymaxfunevals,...
                'MaxIter',mymaxiters,...
                'SearchMethod','GPSPositiveBasisNp1',...
                'PollMethod','GPSPositiveBasis2N',...
                'TolFun',mytolfun,...
                'TolX',mytolx,...
                'PlotFcn',[]);
            [theta2, fval, exit_info, tmp] =...
                patternsearch(@gmmobj,theta2,[],[],[],[],[],[],options);
               counts=tmp.funccount;
        end

        % *****************************************************************
        % GA-GADS
        % *****************************************************************
        if optrout==10
            options=gaoptimset(...
                'TolFun'        ,mytolfun,...
                'Generations'   ,mymaxfunevals,...
                'StallGenLimit' ,50,...
                'StallTimeLimit',1800,...
                'TimeLimit'     ,1800,...
                'Display'       ,'iter');
            rand('state',1000*perturb);
            randn('state',1000*perturb);
            [theta2,fval,reason,tmp,population,scores] =...
                ga(@gmmobj,size(theta2,1),[],[],[],[],[],[],[],options);
                counts=tmp.funccount;
            theta2=theta2';
            exit_info=1;
        end
        
        % *****************************************************************
        % During attempted function evaluations, deltas may be generated
        % with missing values; in this case, use the last vector of deltas
        % with non-missing values
        % *****************************************************************        
        xxx=(1:1:size(mval_track,2))';
        yyy=sum(isnan(mval_track))'==0;
        xxx=max(xxx(yyy==1,:));
        mvalold=mval_track(:,xxx);
        
        if xxx>1
            mvalolds=mval_track(:,[xxx-1,xxx]);
        end
        if xxx==1
            mvalold=mvalold_logit;            
            mvalolds=[mvalold_logit,mvalold];
        end        
       
        counts2    = [counts2;counts];
        perturbs2  = [perturbs2;perturb];
        gmmresids  = [gmmresids,gmmresid];
        deltas     = [deltas,log(mvalold)];
        fvals      = [fvals;fval];
        
        theta2s    = [theta2s;theta2'];

        if isempty(theta1)
            theta1=-999999*ones(size(x1,2),1);
        end
        
        theta1s    = [theta1s;theta1'];
        exit_infos = [exit_infos;exit_info];        

        vcov       = var_cov(theta2);
        se         = full(sqrt(diag(vcov)));
        std_errors = [std_errors;se'];        

        mvalolds2  = [mvalolds2,mvalolds];
        mvalold0   = mvalolds(:,1);
        mvalold00  = mvalolds(:,2);

        mvalold=mvalold00;
        g=gradobj(theta2);
        
        mvalold=mvalold0;
        g2=gradient_vec('gmmobj',theta2);
        
        mvalold=mvalold0;
        H = nevo_hessian_mat('gmmobj',theta2,[]);
        eig_H=eig(reshape(H,size(theta2,1),size(theta2,1)));

        mvalold=mvalold00;
        options = optimset(...
                'MaxFunevals',1,...
                'GradObj',     'on',...
                'HessUpdate',  'bfgs',...
                'LargeScale',  'off',...
                'TolFun',      mytolfun,...
                'TolX',        mytolx,...
                'Display','off');

        [theta2b,fvalb,exit_infob,tmpb,g3,H2]=fminunc('gmmobj2',theta2,options);
        eig_H2=eig(reshape(H2,size(theta2,1),size(theta2,1)));

        %address irregular gradients and hessians
        if (min(g3)==-999999) && (max(g3)==-999999) && (std(g3)==0)           
            g = -999999*ones(size(theta2));
            g2= -999999*ones(size(theta2));
            g3= -999999*ones(size(theta2));
            
            H  = -999999*ones(size(theta2,1),size(theta2,1));
            H2 = -999999*ones(size(theta2,1),size(theta2,1));
            
            eig_H  = -999999*ones(size(theta2));
            eig_H2 = -999999*ones(size(theta2));
            
        end    
                
        fprintf('\nObj. function:\t');
        printm(fval);        
        
        fprintf('\ntheta1:\t');
        printm(theta1');

        fprintf('\ntheta2\t');
        printm(theta2');
                
        fprintf('\ngradient-analytical\n');
        fprintf('%18.4f\n',g);

        fprintf('\ngradient-numerical I\n');
        fprintf('%18.4f\n',g2);
 
        fprintf('\ngradient-numerical II\n');
        fprintf('%18.4f\n',g3);

        fprintf('\nhessian eigenvalues-numerical I\n');
        fprintf('%18.4f\n',eig_H);                       

        fprintf('\nhessian eigenvalues-numerical II\n');
        fprintf('%18.4f\n',eig_H2);                       

        hessians    =[hessians;H(:)'];
        hessians2   =[hessians2;H(:)'];
        gradients   =[gradients;g'];
        gradients2  =[gradients2;g2'];            
        gradients3  =[gradients3;g3'];            
        
        toc_tmp=toc;
        tocs=[tocs;toc];
        
    end %perturbations loop

    %**********************************************************************
    % Save results
    %**********************************************************************
    cd(results_path)
        fprintf('\n');
        fprintf('Saving optimization results...\n');
        save (matfile, 'perturbs2', 'fvals', 'theta1s', 'theta2s','exit_infos',...
             'hessians','hessians2','gradients', 'gradients2' ,'gradients3',...
             'deltas' ,'gmmresids' ,'mvalolds2','std_errors','counts2',...
             'fvals_track','tocs');
    cd(code_path)
    diary off

end %optimization routines loop


