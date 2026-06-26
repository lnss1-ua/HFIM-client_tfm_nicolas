/**
 * HFIM - FIM Benchmark Header
 *
 * Architecture-agnostic QEMU shutdown for FIM benchmarks.
 *
 * Supported architectures:
 * - RISC-V: sifive_test device write (QEMU virt machine)
 * - AArch64: PSCI SYSTEM_OFF via HVC (QEMU virt machine)
 * - ARM32:   semihosting SYS_EXIT
 * - Other:   WFI/WFE loop (FIM detects via GDB breakpoint at fim_exit)
 *
 * The user's benchmark just calls fim_exit(0) — the implementation
 * handles the correct shutdown mechanism per architecture.
 */

#ifndef HFIM_H
#define HFIM_H

#include <stdint.h>

/* sifive_test device address (always present on QEMU virt machine) */
#define SIFIVE_TEST_BASE    0x100000UL

/* Exit codes for sifive_test device */
#define SIFIVE_TEST_PASS    0x5555
#define SIFIVE_TEST_FAIL    0x3333

/* FIM exit codes for benchmark classification */
#define FIM_EXIT_SUCCESS    0   /* Normal completion */
#define FIM_EXIT_FAILURE    1   /* Benchmark detected error (e.g., DMR mismatch) */
#define FIM_EXIT_CRASH      2   /* Unexpected error/crash */

/**
 * Mark the start of the fault injection window.
 *
 * This function serves as a marker for the start of code-under-test in the benchmark.
 * The FIM framework uses GDB to set breakpoints between fim_init() and fim_exit()
 * to inject faults at random code locations during execution.
 *
 * Implementation note:
 * - Non-inline to ensure a stable address in the ELF symbol table
 * - Implemented in fim_instrumentation.c (not header-only)
 * - Has observable side effects to prevent compiler optimization
 *
 * Usage:
 *   Call fim_init() right before the code-under-test begins (after initialization,
 *   before the actual computation that should be tested for fault tolerance).
 */
void fim_init(void);

/**
 * Punctual fault-injection point marker.
 *
 * Place fim_breakpoint() at the exact source location where the campaign
 * should stop the PC and inject a fault. Unlike the [fim_init, fim_exit]
 * window (which the campaign samples by per-PC trip count), this is a single
 * fixed PC. Use it for benchmarks where the window histogram is unreliable,
 * e.g. serial-feeder benchmarks whose UART spin-loop trip counts are not
 * reproducible run-to-run, so a trip-count-weighted draw lands on the spin
 * instead of the code-under-test.
 *
 * Set `inject_at_symbol: fim_breakpoint` in fim.yaml to break here. The
 * symbol address is recompile-stable, unlike a raw `main + 0xNN` byte offset.
 *
 * Implementation note:
 * - Non-inline to ensure a stable address in the ELF symbol table
 * - Implemented in fim_instrumentation.c (not header-only)
 * - Has observable side effects to prevent compiler optimization
 */
void fim_breakpoint(void);

/**
 * Exit QEMU with specified exit code.
 *
 * This function writes to the sifive_test device to terminate QEMU.
 * - code 0: QEMU exits with status 0 (success/masked)
 * - code 1: QEMU exits with status 1 (detected by benchmark)
 * - code >1: QEMU exits with that status (crash/error)
 *
 * This function never returns.
 *
 * Implementation note:
 * - Non-inline to ensure a stable address in the ELF symbol table
 * - Implemented in fim_instrumentation.c (not header-only)
 * - The FIM framework sets a breakpoint at fim_exit() to capture
 *   observable state before the program terminates
 *
 * @param code Exit code (0 = success, 1 = detected, >1 = crash)
 */
void fim_exit(int code) __attribute__((noreturn));

#endif /* HFIM_H */
