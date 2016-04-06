function [cost] = MonthlyCost(Q,L,C,month,c_sumpeak,c_sumpartpeak,c_sum, c_winpartpeak, c_win)
% computes the cost of electricity for one day
% Monthly Cost takes in input:
% month is the month at which optimization is performed
% Cost is the cost vector for electricity rate
% L is the load vector ((24*28, 30 or 31)x1)
% C is the kWh tariffs vector (id) (C=Cost(period))
% Q is the charge load of the battery
% c_sumpeak is the price of max power for the summer during peak hour
% c_sumpartpeak is the price of max power for the summer during partpeak hour
% c_sumoffpeak is the price of max power for the summer during offpeak-hour
% c_winpartpeak is the price of max power for the winter during partpeak-hour
% c_winoffpeak is the price of max power for the winter during offpeak-hour
% (no peak period during the winter)

L_tot=L+Q;
summermonths = 5:10;
wintermonths = [1:4,11:12];
%day1=datenum(datetime(2014,month,1))-datenum('31-December-2013');
%dayend=datenum(datetime(2014,month+1,0))-datenum('31-December-2013');
%monthhours=((day1-1)*24+1:dayend*24)'; %hours of the month
if ~isempty(find(month == summermonths,1))  %summer month
    %find peak hours
    %peakhours=intersect(find(Cost==0.14726),monthhours);
    %peakhours=peakhours-24*(day1-1); %begin month hours to 1
    peakhours=C==0.14726;
    %find part peak hours
    partpeakhours=C==0.10714;
    %compute cost
    cost=L_tot'*C+c_sumpeak*max(L_tot(peakhours))+...
        c_sumpartpeak*max(L_tot(partpeakhours))+c_sum*max(L_tot);
elseif ~isempty(find(month == wintermonths,1))  %winter month
    partpeakhours=C==0.10165;
    cost=L_tot'*C+c_winpartpeak*max(L_tot(partpeakhours))+c_win*max(L_tot);
end

end

