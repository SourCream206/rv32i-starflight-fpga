MEMORY
{
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 4K
    RAM (rw) : ORIGIN = 0x00010000, LENGTH = 1K
}

SECTIONS
{
    .text : {
        *(.boot)    /* Startup assembly MUST be at 0x0 */
        *(.text*)   /* Compiled C code */
        *(.rodata*) /* Read-only data */
    } > ROM

    .data : {
        *(.data*)   /* Initialized variables */
        *(.bss*)    /* Zeroed variables */
    } > RAM

    /* Set stack to top of RAM */
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
}