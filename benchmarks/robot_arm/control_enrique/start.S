.section .text._start
.global _start
_start:
    la sp, stack_top
    call main
loop:
    j loop

.section .bss
.align 4
.space 4096
stack_top: