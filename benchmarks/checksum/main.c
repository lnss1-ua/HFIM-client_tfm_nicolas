/*
 * checksum — cumulative XOR reduction over an array.
 *
 * SDC-prone: a single bit-flip in any intermediate register
 * propagates to the final checksum value. Unlike add_test where
 * each iteration is independent, here every step depends on the
 * previous result.
 */

#include "hfim.h"

#define N 256

volatile unsigned int data[N];
volatile unsigned int checksum;

int main(void) {
    /* Initialize with known pattern */
    for (int i = 0; i < N; i++) {
        data[i] = (unsigned int)(i * 0x01010101u);
    }

    fim_init();

    /* Cumulative XOR — every bit-flip propagates to result */
    unsigned int sum = 0;
    for (int i = 0; i < N; i++) {
        sum ^= data[i];
        sum = (sum << 1) | (sum >> 31);  /* rotate left — spreads corruption */
    }
    checksum = sum;

    fim_exit(0);
}
