%% test script for rhythmic DMP

%# store breakpoints
tmp = dbstatus;
save('tmp.mat','tmp')

%# clear all
close all
clear classes %# clears even more than clear all
clc

%# reload breakpoints
load('tmp.mat')
dbstop(tmp)

%# clean up
clear tmp
delete('tmp.mat')

%% create canonical system

% discretization value - dt
h = 0.01; 
% time constant of the canonical system
ax = 2;
% temporal scaling factor
tau = 1;
% time evolution
tin = 0;
tf = 1;
% tspan = [tin tf];
% number of points
nst = tf/h + 1;
t = tin:h:tf;
% type of pattern to be generated
pat = 'd';
can = Canonical(h,ax,tau,nst,pat);

%% test unforced discrete DMP

% % create two different DMPs
% alpha = 25;
% beta = 25/4;
% goal = 1;
% yin = [0;0];
% numbf = 100;
% dmp1 = discreteDMP(can,alpha,beta,goal,yin,numbf);
% 
% goal = 5;
% yin = [1;0];
% dmp2 = discreteDMP(can,alpha,beta,goal,yin,numbf);
% 
% [x,y1] = dmp1.evolve();
% [~,y2] = dmp2.evolve();
% 
% % plotting each dmp trajectory
% y = y1(1,:);
% figure(1);
% plot(t,y,'-.',t,x,t,dmp1.goal*ones(1,length(t)),'r.');
% legend('state y','phase','goal state');
% title('Unforced trajectory for DMP1');
% 
% y = y2(1,:);
% figure(2);
% plot(t,y,'-.',t,x,t,dmp2.goal*ones(1,length(t)),'r.');
% legend('state y','phase','goal state');
% title('Unforced trajectory for DMP2');

%% test forced discrete DMP and compare LWR vs. simple Regression

% create two different DMPs
alpha = 25;
beta = 25/4;
% number of basis functions
numbf = 50;
% goal and amplitude are initialized here
goal = 1;
% initial states of DMPs
yin1 = [0;0];
yin2 = [0;0];
dmp1 = discreteDMP(can,alpha,beta,goal,yin1,numbf);
dmp2 = discreteDMP(can,alpha,beta,goal,yin2,numbf);

% create two paths
path1 = 5*t.*sin(5*pi/2 * t);
jump2 = floor(length(t)/2);
path2 = [zeros(1,jump2), ones(1,length(t)-jump2)];

% learn the weights with the usual linear regression
dmp1.setWeights(path1);
dmp2.setWeights(path2);

[x,y1] = dmp1.evolve();
[~,y2] = dmp2.evolve();

% plotting each dmp trajectory
y = y1(1,:);
figure(3);
plot(t,path1,'-',t,y,'-.',t,x);
legend('desired trajectory','state y','phase');
title('Followed trajectory for DMP1');

y = y2(1,:);
figure(4);
plot(t,path2,'-',t,y,'-.',t,x);
legend('desired trajectory','state y','phase');
title('Followed trajectory for DMP2');

%% test circular path

% create two paths
path1 = cos(2*pi*t);
path2 = sin(2*pi*t);

% learn the weights with the usual linear regression
dmp1.setWeights(path1);
dmp2.setWeights(path2);

% initial states of DMPs
%yin1 = [1;0];
%yin2 = [0;2*pi];
yin1 = [0;0];
yin2 = [0;0];
dmp1.setInitState(yin1);
dmp1.resetStates();
dmp2.setInitState(yin2);
dmp2.resetStates();

[x,y1] = dmp1.evolve();
[~,y2] = dmp2.evolve();

% plotting each dmp trajectory
y11 = y1(1,:);
figure(5);
plot(t,path1,'-',t,y11,'-.',t,x);
legend('desired trajectory','state y','phase');
title('Followed trajectory for DMP1');

y12 = y2(1,:);
figure(6);
plot(t,path2,'-',t,y12,'-.',t,x);
legend('desired trajectory','state y','phase');
title('Followed trajectory for DMP2');

% plot the x-y trajectory tracked
figure(7);
plot(path1,path2,'-',y11,y12,'-.');
legend('desired trajectory','followed trajectory');
title('Trajectory in xy space');

