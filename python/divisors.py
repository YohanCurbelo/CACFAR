import numpy as np
import my_functions as mf

total_divisors = 128
word_length = 10
fractional_length = 9

divisors = np.zeros(total_divisors)
# Rest 1 because addressing in HW starts at zero
for i in range(len(divisors)-1):
    divisors[i+1] = 1/(i+1)
    
with open("python/divisors.txt",'w') as file:
    # Convert to binary representation
    divisors_b = ["" for i in range(len(divisors))]        
    for i in range(len(divisors)):        
        divisors_b[i] = mf.float_to_bin(divisors[i], word_length, fractional_length)
    # Write txt file
    for line in divisors_b:
        file.write(str(line))
        file.write('\n')