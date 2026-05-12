/**
 * FIM Instrumentation - Fault Injection Window Markers
 *
 * These functions serve as markers for the fault injection framework.
 * They must have stable addresses in the ELF symbol table for GDB to set breakpoints.
 */

#include <stdint.h>
#include "hfim.h"

/**
 * Mark the start of the fault injection window.
 *
 * This function is called by benchmarks to signal the start of code-under-test.
 * The FIM framework uses GDB to set breakpoints between fim_init() and fim_exit()
 * to inject faults at random code locations during execution.
 *
 * Implementation note:
 * - Non-inline to ensure a stable address in the ELF symbol table
 * - Has observable side effects to prevent compiler optimization
 * - Performs a volatile write to ensure it's never removed as dead code
 */
__attribute__((noinline)) void fim_init(void) {
    /* Volatile write to prevent compiler from optimizing this function away */
    /* 0xF1000001 = "FIM init" marker (F1 prefix, 0x00001 = init) */
    volatile uint32_t marker = 0xF1000001;
    (void)marker;  /* Mark as used to suppress warnings */

    /* Memory barrier to prevent reordering */
    asm volatile("" ::: "memory");
}

/**
 * Exit QEMU with specified exit code.
 *
 * This function is the counterpart to fim_init() — it marks the end of the
 * fault injection window. The FIM framework sets a breakpoint here to capture
 * observable state (variable values) before the program terminates.
 *
 * Architecture-specific shutdown:
 * - RISC-V: sifive_test device write at 0x100000 (QEMU virt)
 * - AArch64: PSCI SYSTEM_OFF via HVC (QEMU virt, method="hvc")
 * - ARM32:   semihosting SYS_EXIT
 * - Other:   infinite WFI/WFE loop (FIM detects via breakpoint)
 *
 * Implementation note:
 * - Non-inline to ensure a stable address in the ELF symbol table
 * - The framework resolves fim_exit by name, just like fim_init
 */
__attribute__((noinline, noreturn)) void fim_exit(int code) {

#if defined(__riscv)
    /* RISC-V: sifive_test device (always present on QEMU virt) */
    volatile uint32_t *test_dev = (volatile uint32_t *)SIFIVE_TEST_BASE;
    if (code == 0) {
        *test_dev = SIFIVE_TEST_PASS;
    } else {
        *test_dev = ((uint32_t)code << 16) | SIFIVE_TEST_FAIL;
    }

#elif defined(__aarch64__)
    /* AArch64: PSCI SYSTEM_OFF (0x84000008) via HVC */
    (void)code;
    register uint64_t x0 __asm__("x0") = 0x84000008ULL;
    __asm__ volatile("hvc #0" : : "r"(x0));

#elif defined(__arm__)
    /* ARM32: semihosting angel_SWI SYS_EXIT */
    (void)code;
    register uint32_t r0 __asm__("r0") = 0x18;  /* SYS_EXIT */
    register uint32_t r1 __asm__("r1") = code == 0 ? 0x20026 : 0x20000;
    __asm__ volatile("svc #0x00123456" : : "r"(r0), "r"(r1));

#else
    /* Unknown arch: infinite loop — FIM catches via breakpoint at fim_exit */
    (void)code;
#endif

    /* Should never reach here */
    while (1) {
#if defined(__riscv)
        __asm__ volatile("wfi");
#elif defined(__aarch64__) || defined(__arm__)
        __asm__ volatile("wfe");
#endif
    }
}
