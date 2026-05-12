/*
 * FIM Benchmark Template
 *
 * How to use:
 * 1. Copy this folder:  cp -r benchmarks/template benchmarks/my_algo
 * 2. Write your computation between fim_init() and fim_exit()
 * 3. Declare result variables as global volatile (FIM reads these via GDB)
 * 4. Edit fim.yaml to list your observable variable names
 * 5. Run:  ./run.sh benchmarks/my_algo -n 50
 */

#include "hfim.h"

#define N 16

/* Declare results as global volatile -- FIM reads these after each injection.
 * Must match the variable names in fim.yaml. */
volatile int result[N];

int main(void) {
    /* Setup: initialize inputs BEFORE fim_init()
     * Faults are only injected between fim_init() and fim_exit(),
     * so setup code here runs cleanly every time. */

    fim_init();  /* -- fault injection window starts -- */

    /*
     * YOUR COMPUTATION HERE
     *
     * Rules:
     * - No stdlib (no printf, no malloc). You get <stdint.h> only.
     * - Store results in global volatile variables.
     * - Keep it deterministic (same input = same output).
     */
    for (int i = 0; i < N; i++) {
        result[i] = i * i;
    }

    fim_exit(0); /* -- fault injection window ends -- */
}
