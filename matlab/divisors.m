total_divisors = 128;
word_length = 10;
fractional_length = 9;

div = zeros(1,total_divisors);
% Restamos 1 porque en hardware el direccionamiento comienza en 0
for i = 1:length(div)-1 
    div(i+1) = 1/i;
end

divisors_file = fopen('divisors.txt','w');
q = quantizer('fixed','round','saturate',[word_length fractional_length]);
for i = 1:length(div)
    fprintf(divisors_file,[num2bin(q,div(i)) '\n']);
end