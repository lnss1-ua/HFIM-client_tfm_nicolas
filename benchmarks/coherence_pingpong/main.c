/*
 * coherence_pingpong - phase-6 Ruby coherence stressor.
 *
 * Goal: keep Ruby's TBE/MessageBuffer state populated for the bulk
 * of execution so injectRubyControllerFault has live state to land
 * on. The classic-cache version of this benchmark would do nothing
 * special - L1 hits dominate - but on Ruby every miss spends time
 * in the TBE table while the request walks L1 -> L2 -> directory
 * and back.
 *
 * Why "pingpong" with one CPU: gem5 SE-mode multi-core bare-metal
 * is fragile (shared __stack_top + libcless init). The single-CPU
 * version still produces high TBE/MessageBuffer occupancy because
 * we walk a working-set deliberately larger than L1 + L2 so every
 * iteration takes misses through the coherence hierarchy. Real
 * 2-core ping-pong is phase-6.1 (SPEC out-of-scope).
 *
 * The shared variable PINGPONG_VAR is the address fim_inject_ruby.py
 * should pass as --ruby-target-addr. Its TBE entry will exist
 * whenever a recent load/store on the address is in-flight - which
 * is most of the time when we hammer it in a tight loop.
 */

#include "hfim.h"

/* L1D on the C906 board is 32 KiB. 64 KiB working set guarantees
 * an L1D miss on every access pattern, which means the request
 * goes to L2 - and from L2 to the directory - and back. */
#define WORKING_SET_WORDS 8192    /* 8192 * 8 = 64 KiB */
#define ITERATIONS       512

/* Place at known addresses; injectRubyControllerFault keys on
 * --ruby-target-addr, which the campaign layer reads from the
 * ELF symbol table via riscv64-unknown-linux-gnu-nm. */
volatile unsigned long pingpong_var;
volatile unsigned long working_set[WORKING_SET_WORDS];
volatile unsigned long checksum;

int main(void) {
    fim_init();

    pingpong_var = 0x1111111100000000UL;

    /* Initialize the working set with a known pattern. */
    for (int i = 0; i < WORKING_SET_WORDS; i++) {
        working_set[i] = (unsigned long)i;
    }

    /* The hot loop. Mix of:
     *   - hammer pingpong_var (the symbol we'll inject into)
     *   - large-stride walk through working_set (forces L2 + memory
     *     traffic; keeps the TBE table populated with in-flight
     *     misses for those addresses too)
     */
    unsigned long sum = 0;
    for (int iter = 0; iter < ITERATIONS; iter++) {
        /* Read-modify-write the target. Each RMW is a coherence
         * upgrade transaction in Ruby - TBE allocated until the
         * line is in modified state. */
        pingpong_var = pingpong_var + 1;
        sum = sum + pingpong_var;

        /* Large-stride walk to keep multiple lines in flight.
         * Stride = 8 words = 64 bytes = one cache line, so every
         * access misses. */
        for (int i = 0; i < WORKING_SET_WORDS; i += 8) {
            working_set[i] = working_set[i] + iter;
            sum = sum + working_set[i];
        }
    }

    checksum = sum;

    /* If a fault corrupted any working_set entry or pingpong_var,
     * sum will differ from the golden value. The comparison happens
     * in the host classifier; we just emit. */
    fim_exit(0);
}
