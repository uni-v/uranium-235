// See LICENSE for license details.

#include <stdio.h>

int main() {
    unsigned int ival = 0x235;
    float fval = 2.35f;
    printf("Hello, U%x!\n", ival);
    printf("Hello, U%.2f!\n", fval);
    return 0;
}
