% function from file exchange on mathworks' site
% original name: shuffle_better
function [y] = shuffle(x)
n = length(x);
r = randperm(n);
for i = 1:n
y(r(i)) = x(i);
end
end