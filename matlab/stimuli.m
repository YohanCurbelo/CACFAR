total_samples = 80;
word_length = 16;
fractional_length = 14;
min = 0;
max = 2;

input = (max-min).*rand(total_samples,1) + min;

stimuli_file = fopen('stimuli.txt','w');
q = quantizer('fixed','round','saturate',[word_length fractional_length]);
for i = 1:length(input)
    fprintf(stimuli_file,[num2bin(q,input(i)) '\n']);
end