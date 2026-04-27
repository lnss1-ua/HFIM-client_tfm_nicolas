/*
 * FIM Benchmark Template
 *
 * 1. Rename this folder to your benchmark name
 * 2. Write your computation between fim_init() and fim_exit()
 * 3. Declare result variables as global volatile
 * 4. Create fim.yaml listing your observable variables
 * 5. Build: ./build.sh benchmarks/your_name
 * 6. Upload and run from the FIM server
 */

#include "fim_exit.h"

#define N 16

/* Declare result as global volatile — FIM reads this after each injection */
volatile int result[N];

int main(void) {
    /* Setup: initialize inputs BEFORE fim_init() */
    /* (faults are only injected between fim_init and fim_exit) */

    fim_init();

    /*
     * YOUR COMPUTATION HERE
     *
     * Example: element-wise operation
     */
    for (int i = 0; i < N; i++) {
        result[i] = i * i;
    }

    fim_exit(0);
}
