/*
 * bitcount — population count (Hamming weight) over an array.
 *
 * Bit manipulation heavy: shifts, masks, additions.
 * A bit-flip during counting corrupts the tally but not the
 * source data — tests fault masking in bit-parallel operations.
 */

#include "hfim.h"

#define N 128

volatile unsigned int data[N];
volatile unsigned int result[N];
volatile unsigned int total;

/* Kernighan's bit counting algorithm */
static unsigned int popcount(unsigned int x) {
    unsigned int count = 0;
    while (x) {
        x &= (x - 1);
        count++;
    }
    return count;
}

int main(void) {
    /* Initialize with varying bit patterns */
    for (int i = 0; i < N; i++) {
        data[i] = (unsigned int)(i * 0xDEAD0001u + 0x12345678u);
    }

    fim_init();

    unsigned int sum = 0;
    for (int i = 0; i < N; i++) {
        result[i] = popcount(data[i]);
        sum += result[i];
    }
    total = sum;

    fim_exit(0);
}
