function [cost] = DailyCost_15min(Q,L,C,month,c_sumpeak,c_sumpartpeak,c_sum, c_winpartpeak, c_win)
% computes the cost of electricity for one day
% Daily Cost takes in input:
% L is the load vector (24x1)
% C is the kWh tariffs vector (24x1)
% Q is the charge load of the battery

L_tot=L+Q;
summermonths = 5:10;
wintermonths = [1:4,11:12];
monthlength=[31,28,31,30,31,30,31,31,30,31,30,31];
daysinmonth=monthlength(month);
c_sumpeak_scaled=c_sumpeak/daysinmonth;
c_sumpartpeak_scaled=c_sumpartpeak/daysinmonth;
c_sum_scaled=c_sum/daysinmonth;
c_winpartpeak_scaled=c_winpartpeak/daysinmonth;
c_win_scaled=c_win/daysinmonth;

if ~isempty(find(month == summermonths,1))  %summer month
    peakhours= C==0.14726;
    partpeakhours= C==0.10714;
    cost=0.25*L_tot'*C+c_sumpeak_scaled*max(L_tot(peakhours))+...
        c_sumpartpeak_scaled*max(L_tot(partpeakhours))+c_sum_scaled*max(L_tot);
elseif ~isempty(find(month == wintermonths,1))  %winter month
    partpeakhours= C==0.10165;
    cost=0.25*L_tot'*C+c_winpartpeak_scaled*max(L_tot(partpeakhours))+...
        c_win_scaled*max(L_tot);
end


