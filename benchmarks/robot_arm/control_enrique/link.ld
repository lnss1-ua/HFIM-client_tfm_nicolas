ENTRY(_start)
SECTIONS {
    . = 0x80200000;
    .text : {
        *(.text._start)
        *(.text*)
    }
    .data : { *(.data) }
    .bss  : { *(.bss) }
}