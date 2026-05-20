/*
 * wearstorm - synthetic NVMain endurance driver.
 *
 * Goal: hammer a small (~256 B) memory region with >=10K writes so
 * NVMain's BitModel can record worstCaseWrite values large enough
 * to trip the EnduranceDistMean threshold and surface
 * outcome=stuck_after_wear in injections.csv.
 *
 * Phase-4a A4.8 was honest-skip because fibonacci does ~64 writes
 * to result[] and that never approached even the lowered 1000-cycle
 * BitModel threshold. wearstorm does ITER*N (10000) writes to a
 * 32-byte cell, each cell taking ~312 writes - well above the
 * BitModel EnduranceDistMean=1000 in
 * fim/configs/nvmain/PCM_ISSCC_2012_4GB_BitModel.config.
 *
 * Result[] is volatile so the compiler cannot hoist the writes out
 * of the loop; each iteration produces an actual memory store.
 */

#include "hfim.h"

/* gem5 c906 has L1D 32 kB / L2 256 kB / 64 B line. To force writes
   ALL the way through to NVMain we must defeat both. Use 512 kB so
   the working set is 2x L2 and every L2 line evicts to NVMain on
   each pass. With N=524288 and ITER=20 that's ~10.5M stores +
   ~163K NVMain writes spread across the region - well above BitModel
   EnduranceDistMean=1000. */
#define N 524288   /* 512 kB - 2x L2 capacity */
#define ITER 80    /* 524288 * 80 = ~42M stores. Empirically: at
                      ITER=20 we saw worstCaseEndurance drop from
                      1000 to 476 (524 writes on the worst cell).
                      4x more iterations should drive worstCase below
                      0 and trigger stuck_after_wear. */

volatile unsigned char result[N];

int main(void) {
    fim_init();

    /* zero the region so worstCaseWrite reflects fresh hits, not
       static-init writes from libc. */
    for (int i = 0; i < N; i++) {
        result[i] = 0;
    }

    /* Hammer pattern: each cell sees a strictly-changing byte stream
       so write-combining at the bank can't merge consecutive writes.
       Mix the iteration index and cell index across all 8 bits so
       each write differs from the previous one in multiple bit
       positions - this drives per-cell wear under BitModel.

       The volatile qualifier on result[] prevents the compiler from
       hoisting the inner store. */
    unsigned long counter = 0;
    for (int k = 0; k < ITER; k++) {
        for (int i = 0; i < N; i++) {
            counter += 0x9E3779B97F4A7C15UL; /* 2^64 / phi (Knuth) */
            result[i] = (unsigned char)((counter >> ((i & 7) * 8)) & 0xFF);
        }
    }

    fim_exit(0);
}
