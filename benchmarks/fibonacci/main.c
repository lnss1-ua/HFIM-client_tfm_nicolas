/*
 * fibonacci — compute first 64 Fibonacci numbers iteratively.
 *
 * Sequential dependency chain: each number depends on the
 * previous two. A bit-flip in any intermediate value corrupts
 * all subsequent entries. High SDC propagation rate.
 */

#include "fim_exit.h"

#define N 64

volatile unsigned long result[N];

int main(void) {
    fim_init();

    result[0] = 0;
    result[1] = 1;
    for (int i = 2; i < N; i++) {
        result[i] = result[i - 1] + result[i - 2];
    }

    fim_exit(0);
}
