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
%Define paths and files for input and output
%**************************************************************************
code_path    =pwd;
results_path =[code_path,'\optimization results\'];
logs_path    =[code_path,'\optimization logs\'];
add_path     =[code_path,'\optimization routines\'];

excel_file='Optimization results.xls';
csv_file  ='Optimization results.csv';

addpath(add_path);

%**************************************************************************
%Collect all the infromation tracked by the various optimization routines
%**************************************************************************
fvals_all=[];
perturbs_all=[];
counts_all=[];
exit_infos_all=[];

thetas_all=[];

gradients_all=[];
gradients_all2=[];
gradients_all3=[];

hessians_all=[];
hessians_all2=[];

std_errors_all=[];

tocs_all        =[];
optrout_no_all  =[];

cd(results_path);

%**************************************************************************
%Loop over the various optimization routines
%**************************************************************************
for i=1:10
    
    if i<=9
        matfile=['nevo_0',num2str(i),'_data_optim'];
    else
        matfile=['nevo_',num2str(i),'_data_optim'];
    end
    
    load (matfile, 'perturbs2','fvals', 'theta1s', 'theta2s','exit_infos',...
                   'hessians','hessians2','gradients', 'gradients2',...
                   'gradients3','deltas' ,'gmmresids' ,'mvalolds2',...
                   'std_errors','counts2','fvals_track','tocs'); 
                                
    optrout_no      =repmat(i,size(fvals,1),1);
    optrout_no_all  =[optrout_no_all;optrout_no];
    fvals_all       =[fvals_all;fvals]; 
    perturbs_all    =[perturbs_all;perturbs2];
    counts_all      =[counts_all;counts2];
    exit_infos_all  =[exit_infos_all;exit_infos];    
    thetas_all      =[thetas_all;[theta1s,theta2s]];
    gradients_all   =[gradients_all;gradients];
    gradients_all2  =[gradients_all2;gradients2];
    gradients_all3  =[gradients_all3;gradients3];
    hessians_all    =[hessians_all;hessians];
    hessians_all2   =[hessians_all2;hessians2];
    std_errors_all  =[std_errors_all;std_errors];
    tocs_all        =[tocs_all;tocs];    
end

%**************************************************************************
%Retrieve norm-inf for gradients and hessian eigenvalues
%**************************************************************************
grad_inf=[];
grad_inf2=[];
grad_inf3=[];
hessian_eigs=[];
hessian_eigs2=[];

for i=1:size(gradients_all,1)
    grad_inf(i,:)=norm(gradients_all(i,:),inf);
    grad_inf2(i,:)=norm(gradients_all2(i,:),inf);
    grad_inf3(i,:)=norm(gradients_all3(i,:),inf);       

    if max(hessians_all(i,:))~=-999999
        hessian_eigs(i,:)=eig(reshape(hessians_all(i,:),13,13));
        hessian_eigs2(i,:)=eig(reshape(hessians_all2(i,:),13,13));
    else
        hessian_eigs(i,:)=-999999*ones(1,13);
        hessian_eigs2(i,:)=-999999*ones(1,13);    
    end
    
end

%**************************************************************************
%Create cells for the various matrices to be saved in an Excel file
%**************************************************************************
optrout_no_all_cell     = num2cell(optrout_no_all);
perturbs_all_cell       = num2cell(perturbs_all);
counts_all_cell         = num2cell(counts_all);
exit_infos_all_cell     = num2cell(exit_infos_all);
tocs_all_cell           = num2cell(tocs_all);

fvals_all_cell          = num2cell(fvals_all);
thetas_all_cell         = num2cell(thetas_all);
std_errors_all_cell     = num2cell(std_errors_all);

gradients_all_cell      = num2cell(gradients_all);
gradients_all2_cell     = num2cell(gradients_all2);
gradients_all3_cell     = num2cell(gradients_all3);

grad_inf_cell  = num2cell(grad_inf);
grad_inf2_cell = num2cell(grad_inf2);
grad_inf3_cell = num2cell(grad_inf3);

hessian_eigs_cell  = num2cell(hessian_eigs);
hessian_eigs2_cell = num2cell(hessian_eigs2);

fvals_header           ={'optmethod','stvalue','fcn_evals','exit_info','toc','fval'};
thetas_header          ={'optmethod','stvalue','price','brand1','brand2','brand3','brand4','brand5','brand6',...
                        'brand7','brand8','brand9','brand10','brand11','brand12',...
                        'brand13','brand14','brand15','brand16','brand17','brand18',...
                        'brand19','brand20','brand21','brand22','brand23','brand24',...
                        'const_sigma','price_sigma','sugar_sigma','mushy_sigma',...
                        'const_inc','price_inc','sugar_inc','mushy_inc','price_inc2',...
                        'const_age','sugar_age','mushy_age','price_child'};

gradients_header        ={'optmethod','stvalue','const_sigma','price_sigma','sugar_sigma','mushy_sigma',...
                        'const_inc','price_inc','sugar_inc','mushy_inc','price_inc2',...
                        'const_age','sugar_age','mushy_age','price_child','norm_inf'};
                    
hessians_header         ={'optmethod','stvalue','eig1','eig2','eig3','eig4','eig5','eig6','eig7','eig8','eig9','eig10','eig11','eig12','eig13'};

fvals_data              = [optrout_no_all_cell,perturbs_all_cell,counts_all_cell,exit_infos_all_cell,tocs_all_cell,fvals_all_cell];
fvals_excel             = [fvals_header;fvals_data];

thetas_data             = [optrout_no_all_cell,perturbs_all_cell,thetas_all_cell];
thetas_excel            = [thetas_header;thetas_data];

gradients_data          = [optrout_no_all_cell,perturbs_all_cell,gradients_all_cell,grad_inf_cell];
gradients_excel         = [gradients_header;gradients_data];

gradients2_data         = [optrout_no_all_cell,perturbs_all_cell,gradients_all2_cell,grad_inf_cell];
gradients2_excel        = [gradients_header;gradients2_data];

gradients3_data         = [optrout_no_all_cell,perturbs_all_cell,gradients_all3_cell,grad_inf_cell];
gradients3_excel        = [gradients_header;gradients3_data];

hessians_data           = [optrout_no_all_cell,perturbs_all_cell,hessian_eigs_cell];
hessians_excel          = [hessians_header;hessians_data];

hessians2_data          = [optrout_no_all_cell,perturbs_all_cell,hessian_eigs2_cell];
hessians2_excel         = [hessians_header;hessians2_data];

xlswrite(excel_file,fvals_excel,          'fvals');
xlswrite(excel_file,thetas_excel,        'thetas');
xlswrite(excel_file,gradients_excel,  'gradients');
xlswrite(excel_file,gradients2_excel,'gradients2');
xlswrite(excel_file,gradients3_excel,'gradients3');
xlswrite(excel_file,hessians_excel,    'hessians');
xlswrite(excel_file,hessians2_excel,  'hessians2');

%**************************************************************************
%Save also a CSV file 
%**************************************************************************
csv_mat=[optrout_no_all,perturbs_all,counts_all,exit_infos_all,tocs_all,...
         fvals_all,thetas_all,std_errors_all,gradients_all,grad_inf,...
         gradients_all2,grad_inf2,gradients_all3,grad_inf3,hessian_eigs,...
         hessian_eigs2];

csvwrite(csv_file,csv_mat);
cd(code_path);
               
               
               
