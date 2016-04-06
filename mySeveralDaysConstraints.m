function [c,ceq] = mySeveralDaysConstraints(Q,L,q,S)
% constraints are determined by
% q : max charge rate of battery
% S : max storage of battery
% L : load profile
% Z : charge state of the battery

% Z = [q1, q1+q2, ... , q1+q2+...+q_(end)]
Z = cumsum(Q);
% -q <= Q <=q
% 0 <= Z <= S
% L+Q >= 0 (load must stay non-negative)
% 0.95*Z(1)<=Z(N)<=1.05*Z(1)
c=[Q-q;-Q-q;-(L+Q);-Z;Z-S];
ceq=[];
n=length(Q)/24;
for i=1:n
    ceq=[ceq Z(24*i)];
end
end



