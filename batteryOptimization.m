clc, clearvars, close all
countfig=1;
%% Section 1a: Get the load data
data = csvread('PGE_electric_2014-01-01_to_2014-12-31.csv',1,3);
[ntimes,nbldgs]=size(data);
%ntime = 8759 = 24x365-1 rows for hourly data during one year
%nbldgs = 23 columns for 23 different buildings
%time = 1:ntimes;

%% Section 1b: Get the cost data
% In 2014, year began on Wednesday
% PG&E tariffs E-19 (Medium General Demand-Metered TOU Service) are:
% ENERGY RATES -------------------------------------
%           PEAK            PART-PEAK       OFF-PEAK
% SUMMER    $0.14726        $0.10714        $0.08057
% WINTER    -               $0.10165        $0.08717
% DEMAND RATES -------------------------------------
%           PEAK            PART-PEAK       OFF-PEAK
% SUMMER    $18.74          $5.23           $17.33
% WINTER    -               $0.13           $17.33
%              -------------------------------------
% SUMMER:   PEAK: 12:00 noon to 6:00 p.m. Monday through Friday
%           PART-PEAK: 8:30 am to 12:00 noon Mon thu Fri
%           OFF-PEAK: All other hours
% WINTER:   PART-PEAK: 8:30 am to 9:30 pm Mon thru Fri
%           OFF-PEAK: All other hours
%
% We have hourly data. Time period are rounded to the inferior hour.

fd = 3; %first day of the year
summer = 120*24+1:304*24; %May 1st to October 31st
winter = [1:120*24,304*24+1:365*24-1]; %Rest of the year
Cost = zeros(8760,1);
for hour=1:8760
    dayhour = mod(hour,24);
    day = (hour-dayhour)/24+1;
    weekday = mod(day+fd-2,7)+1; %1: Monday, 2: Tuesday etc.
    if ~isempty(find(summer==hour,1)) %%hour is in summer
        if dayhour<=17 && dayhour>=12 && weekday<=5 %%peak
            Cost(hour) = 0.14726;
        elseif dayhour<=12 && dayhour>=8 && weekday<=5 %%part-peak
            Cost(hour) = 0.10714;
        else %%off peak
            Cost(hour) = 0.08057;
        end
    else %%hour is in winter
        if dayhour<=21 && dayhour>=8 && weekday<=5 %%part-peak
            Cost(hour) = 0.10165;
        else %%off peak
            Cost(hour) = 0.08717;
        end
    end
end

c_sumpeak = 18.74;
c_sumppeak = 5.23;
c_sum = 17.33;
c_winppeak = 0.13;
c_win = 17.33;

%% Section 2: visualize data
bldg = 1;
days = {'1-January-2014','1-April-2014','1-July-2014','1-October-2014'};
ndays=datenum(days)-datenum('31-December-2013');
figure(countfig);countfig=countfig+1;
for i = 1:numel(ndays)
    day = ndays(i);
    plot(1:24, data(24*(day-1)+1:24*day,bldg),'-o','linewidth',2,'markersize',3)
    hold on
end
title(sprintf('Visualization of some Load Daily Profiles for Building %d',bldg));
legend(days,'Location','northwest')
xlim([1,24]);
xlabel('Time (h)')
ylabel('Hourly energy consumption (kWh)');
grid on

days = {'1-January-2014','1-July-2014'};
ndays=datenum(days)-datenum('31-December-2013');
figure(countfig);countfig=countfig+1;
for i=1:numel(ndays)
    subplot(2,1,i);
    day = ndays(i);
    plot(1:24,Cost(24*(day-1)+1:24*day));
    title(sprintf('PG&E Electricity Tariffs on %s',days{i}));
    xlabel('Hour of day');
    ylabel('Electricity Cost ($/kWh)');
    xlim([1 24]);
    grid on
end

%% Battery Modeling
% Tesla PowerWall
S = 6.4; %kWh
q = 3.3; %kW

%% Single-Day Optimization
% Choose your day
date = '15-August-2014';
day=datenum(date)-datenum('31-December-2013');
dt=datetime(date);
month=dt.Month;
period = (day-1)*24+1:day*24;

% Choose your building
bldg = 2;

% Load vector
L = data(period,bldg);

% Cost vector
C = Cost(period);

% Optimization functions
%f=@(Q) DailyCost(Q,L,C); %cost function
f=@(Q) DailyCost2(Q,L,C,month,c_sumpeak,c_sumppeak,c_sum,c_winppeak,c_win);
c=@(Q) myConstraints(Q,L,q,S); %constraint function

%solve
options = optimoptions(@fmincon,...
    'Display','none','Algorithm','interior-point');
Q_init=zeros(24,1);
cost_init=f(Q_init);
[Q,cost] = fmincon(f,Q_init,...
    [],[],[],[],[],[],c,options);

%% Plot single-day results
figure(countfig);countfig=countfig+1;
time=1:24;
Z = cumsum(Q);

subplot(3,1,[1 2])
[hAx,hLine1,hLine2]=plotyy(time,[L,Q,L+Q],time,Z);
legend('Load profile (kWh)','Battery consumption (kWh)','Total load (kWh)','State of battery')
title(sprintf('Battery Optimization for Building %d on %s',[bldg,date]));
ylabel(hAx(1),'Load (kW)')
ylabel(hAx(2),'state of battery (kWh)')
for i=1:3
    hLine1(i).LineWidth=2;
end
hLine2.LineStyle=':';
hLine2.LineWidth=2;
grid on
xlim([1,24]);

subplot(3,1,3);
plot(time,C,'-k','linewidth',2,'markersize',3)
xlabel('Time (h)')
ylabel('kWh price ($)')
legend('Cost ($/kWh)')
title(sprintf('PG&E Electricity Tariffs on %s',date));
xlim([1,24]);
grid on

% Display results
fprintf('Cost without battery: $%.2f \n',cost_init);
fprintf('Cost with battery: $%.2f \n',cost);
fprintf('You save $%.2f i.e. %.1f%% \n',cost_init-cost, 100*(cost_init-cost)/(cost_init));

%% Several days optimization

% Choose your days
datestart = '1-April-2014';
dateend = '5-April-2014';
day1=datenum(datestart)-datenum('31-December-2013');
dayend=datenum(dateend)-datenum('31-December-2013');
period =((day1-1)*24+1:dayend*24)';

% Choose your building
bldg = 3;

% Load vector
L = data(period,bldg);

% Cost vector
C = Cost(period);

% Optimization functions
f=@(Q) DailyCost(Q,L,C); %cost function
c=@(Q) mySeveralDaysConstraints(Q,L,q,S); %constraint function

%solve
options = optimoptions(@fmincon,...
    'Display','none','Algorithm','interior-point');
Q_init=zeros(length(period),1);
warning('off')
[Q,cost] = fmincon(f,Q_init,...
    [],[],[],[],[],[],c,options);

%% Plot several days results
figure(countfig);countfig=countfig+1;
nhours=length(period);
time=1:nhours;
Z = cumsum(Q);

subplot(3,1,[1,2])
[hAx,hLine1,hLine2]=plotyy(time,[L,Q,L+Q],time,Z);
legend('Load profile (kWh)','Battery consumption (kWh)','Total load (kWh)','State of battery')
title(sprintf('Battery Optimization for Building %d from %s to %s',bldg,datestart,dateend));
ylabel(hAx(1),'Load (kW)')
ylabel(hAx(2),'state of battery (kWh)')
for i=1:3
    hLine1(i).LineWidth=2;
end
hLine2.LineStyle=':';
hLine2.LineWidth=2;
grid on
xlim([1,nhours]);

subplot(313)
plot(time,C,'-k','linewidth',2)
xlabel('Time (h)')
ylabel('kWh price ($)')
legend('Cost ($/kWh)')
title(sprintf('PG&E Electricity Tariffs from %s to %s',datestart,dateend));
xlim([1,nhours]);
grid on

% Display results
fprintf('Cost without battery: $%.2f \n',C'*L);
fprintf('Cost with battery: $%.2f \n',cost);
fprintf('You save $%.2f i.e. %.1f%% \n',-C'*Q, 100*(-C'*Q)/(C'*L));

%% One-Month Optimization

% Choose your month
month = 6;
day1=datenum(datetime(2014,month,1))-datenum('31-December-2013');
dayend=datenum(datetime(2014,month+1,0))-datenum('31-December-2013');
period =((day1-1)*24+1:dayend*24)';
n=24;

% Choose your building
bldg = 1;

% Load vector
L = data(period,bldg);

% Cost vector
C = Cost(period);

% Optimization functions
f=@(Q) MonthlyCost(Q,L,C,month,c_sumpeak,c_sumppeak,c_sum, c_winppeak, c_win); %cost function
c=@(Q) myConstraints(Q,L,q,S); %constraint function

%% Solve One-Month Optimization
options = optimoptions(@fmincon,...
    'Display','none','Algorithm','interior-point');
Q_init=zeros(length(period),1);
c_init=f(Q_init);
[Q,cost] = fmincon(f,Q_init,...
    [],[],[],[],[],[],c,options);

%% Plot One-Month Results
figure(countfig);countfig=countfig+1;
nhours=length(period);
time=1:nhours;
Z = cumsum(Q);

subplot(311)
plot(time,[L,Q,L+Q],'-')
legend('Load profile (kWh)','Battery consumption (kWh)','Total load (kWh)')
title(sprintf('Battery Optimization for Building %d on month %d',[bldg,month]));
ylabel('Load (kW)')
grid on
xlim([1,nhours]);

subplot(312)
plot(time,Z,'-g')
legend('State of battery')
ylabel('state of battery (kWh)')
grid on
xlim([1,nhours]);

subplot(313)
plot(time,C,'-k')
xlabel('Time (h)')
ylabel('kWh price ($)')
legend('Cost ($/kWh)')
title(sprintf('PG&E Electricity Tariffs for month %d',month));
xlim([1,nhours]);
grid on

% Display results
fprintf('Cost without battery: $%.2f \n',c_init);
fprintf('Cost with battery: $%.2f \n',cost);
fprintf('You save $%.2f i.e. %.1f%% \n',c_init-cost,100*(c_init-cost)/c_init);
if c_init-cost<=0
    fprintf('Optimization failed \n')
end


%% Enter parameters
L=[1.48,1.49,1.55,1.49,1.79,2.71,2.28,2.66,1.96,1.66,1.31,1.44,1.5,1.31,1.81,1.93,2.06,2.58,2.58,2.07,1.99,1.74,1.62,1.55]';
C=[0.12989,0.12989,0.12989,0.12989,0.12989,0.12989,0.12989,0.12989,0.12989,0.12989,0.12989,0.37804,0.37804,0.37804,0.37804,0.37804,0.37804,0.37804,0.12989,0.12989,0.12989,0.12989,0.12989,0.12989]';
c_low=1;c_med=2;c_high=4;
q=5;S=12;

%% Define functions
f=@(Q) DailyCost(Q,L,C);
c=@(Q) myConstraints(Q,L,q,S);

%% Optimize
options = optimoptions(@fmincon,...
    'Display','none','Algorithm','interior-point');
Q_init=zeros(24,1);
[Q,cost] = fmincon(f,Q_init,...
    [],[],[],[],[],[],c,options)

%% Plot results
figure(countfig);countfig=countfig+1;
time=1:24;
Z = cumsum(Q);
subplot(211)
plot(time,[L,Q,L+Q],'-o','linewidth',2,'markersize',3)
legend('L','Q','L+Q')
xlabel('time (h)')
ylabel('Load (kW)')
grid on
subplot(212)
plot(time,Z,'-o','linewidth',2,'markersize',3)
legend('Z')
xlabel('time (h)')
ylabel('state of battery (kWh)')
grid on

%% Influence of q
% Optimize
q=linspace(1,5,10);
S=12;
costs=[];
for qq=q
    c=@(Q) myConstraints(Q,L,qq,S);
    options = optimoptions(@fmincon,...
        'Display','none','Algorithm','interior-point');
    Q_init=zeros(24,1);
    [~,cost] = fmincon(f,Q_init,...
        [],[],[],[],[],[],c,options);
    costs=[costs, cost];
end

% Display C*=f(q)
figure(countfig);countfig=countfig+1;
plot(q,costs,'-o','linewidth',2,'markersize',3)
ylabel('minimal cost ($)')
xlabel('max charge rate (kW)')
title(sprintf('Evolution of minimal cost vs battery max charge rate, S=%dkWh',S));
grid on

%% Influence of S
% Optimize
S=linspace(1,20,10);
q=2.5;
costs=[];
for ss=S
    c=@(Q) myConstraints(Q,L,q,ss);
    options = optimoptions(@fmincon,...
        'Display','none','Algorithm','interior-point');
    Q_init=zeros(24,1);
    [~,cost] = fmincon(f,Q_init,...
        [],[],[],[],[],[],c,options);
    costs=[costs, cost];
end

% Display C*=f(S)
figure(countfig);countfig=countfig+1;
plot(S,costs,'-o','linewidth',2,'markersize',3)
ylabel('minimal cost ($)')
xlabel('max battery storage (kWh)')
title(sprintf('Minimal cost vs battery storage capacity, q=%.1fkWh',q));
grid on

%% PV
G_low = 1e-3 *[0. 0. 0. 0. 0. 0. 0. 28.061 256.127 355.908 418.601 2268.482 2279.312 2038.431 1418.286 651.275 224.252 0. 0. 0. 0. 0. 0. 0.]';
G_high = 1e-3 *[0. 0. 0. 0. 0. 55.713 321.051 483.474 747.841 999.394 2633.293 3181.018 3275.846 3105.654 2717.542 2195.19 1474.313 693.406 148.313 25.044 0. 0. 0. 0.]';
figure(countfig);countfig=countfig+1;
subplot(211)
plot(time,[L,G_low, G_high],'-o','linewidth',2,'markersize',3);
grid on
xlabel('time (h)')
ylabel('Load and Generation (kW)')
legend('L','G - January','G - June')
subplot(212)
plot(time,[L-G_low, L-G_high],'-o','linewidth',2,'markersize',3);
grid on
xlabel('time (h)')
ylabel('Load minus Generation (kW)')
legend('L-G (January)','L-G (June)')

%% Cost of PV

cost1 = DailyCost(-G_low,L,C);
cost2 = DailyCost(-G_high,L,C);

cost1 = cost1*ones(numel(S),1);
cost2 = cost2*ones(numel(S),1);

figure(countfig);countfig=countfig+1;
hold on
plot(S,costs,'-o','linewidth',2,'markersize',3)
plot(S,[cost1,cost2],'linewidth',2)
ylabel('minimal cost ($)')
xlabel('max battery storage (kWh)')
legend('Battery','PV - January','PV - June')
title(sprintf('Minimal cost vs battery storage capacity, q=%.1fkWh',q));
grid on
hold off
