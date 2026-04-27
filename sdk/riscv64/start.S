/* Minimal RISC-V startup for QEMU virt bare-metal */
.section .text.start
.global _start
_start:
    /* Enable FPU: set mstatus.FS = 01 (Initial) */
    li t0, (1 << 13)
    csrs mstatus, t0

    la sp, __stack_top
    call main
1:  wfi
    j 1b
