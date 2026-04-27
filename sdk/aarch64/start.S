/* Minimal AArch64 startup for QEMU virt bare-metal */
.section .text.start
.global _start
_start:
    /* Enable FPU/SIMD: set CPACR_EL1.FPEN = 0b11 (bits 21:20) */
    mov x0, #(3 << 20)
    msr cpacr_el1, x0
    isb

    ldr x0, =__stack_top
    mov sp, x0
    bl main
1:  wfi
    b 1b
