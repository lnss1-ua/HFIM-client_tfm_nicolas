/*
 * mmult — 16x16 integer matrix multiplication: C = A * B
 *
 * Heavy register pressure from nested loops and accumulation.
 * A single bit-flip in the accumulator corrupts one cell of the
 * result matrix — high SDC surface.
 */

#include "fim_exit.h"

#define N 16

volatile int A[N * N];
volatile int B[N * N];
volatile int result[N * N];

int main(void) {
    /* Initialize matrices with deterministic values */
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            A[i * N + j] = i + j + 1;
            B[i * N + j] = (i == j) ? 2 : (i * 3 + j) % 7;
        }
    }

    fim_init();

    /* Matrix multiply: result = A * B */
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            int acc = 0;
            for (int k = 0; k < N; k++) {
                acc += A[i * N + k] * B[k * N + j];
            }
            result[i * N + j] = acc;
        }
    }

    fim_exit(0);
}
