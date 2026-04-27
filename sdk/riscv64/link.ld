/* Generic RISC-V bare-metal linker script for QEMU virt */
ENTRY(_start)

MEMORY {
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 64M
}

SECTIONS {
    .text : { *(.text.start) *(.text*) } > RAM
    .rodata : { *(.rodata*) } > RAM
    .data : { *(.data*) *(.sdata*) } > RAM
    .bss : {
        __bss_start = .;
        *(.bss*) *(.sbss*) *(COMMON)
        __bss_end = .;
    } > RAM
    . = ALIGN(16);
    __stack_bottom = .;
    . += 0x1000;
    __stack_top = .;
}
