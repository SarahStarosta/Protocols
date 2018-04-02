clear 
close all
depl=0.8;
value(1)=18
for i = 2:13
    
    value(i)= value(i-1)*depl
    
end

bar(value)
mean(value)