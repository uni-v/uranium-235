// See LICENSE for license details.

#include <stdio.h>
#include <stdint.h>

int main(int argc, char **argv) {
    uint32_t bin_val;
    printf("Please input the binary value in hex (e.g. 0xcafe0235): ");
    scanf("0x%x", &bin_val);
    float fp_val;
    fp_val = *((float *) &bin_val);
    printf("The float value of binary 0x%08x is %f\n", bin_val, fp_val);
    return 0;
}
