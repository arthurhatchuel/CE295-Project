function [cost] = DailyCost(Q,L,C)
% computes the cost of electricity for one day
% Daily Cost takes in input:
% L is the load vector (24x1)
% C is the kWh tariffs vector (24x1)
% Q is the charge load of the battery

L_tot=L+Q;
cost=L_tot'*C;

end

