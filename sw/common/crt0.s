# ============================================================================
# File: crt0.s
# Description: Bare-metal C Runtime Startup Code for AZ_V CPU
# Project: AZ_V RISC-V CPU
# ============================================================================

.section .text.init
.global _start
.type _start, @function

_start:
    # Initialize Stack Pointer (sp)
    la sp, __stack_top

    # Zero out BSS section
    la t0, __bss_start
    la t1, __bss_end
.L_bss_loop:
    bgeu t0, t1, .L_bss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j .L_bss_loop

.L_bss_done:
    # Call main(argc=0, argv=NULL)
    li a0, 0
    li a1, 0
    call main

    # Main returned: Write exit code (in a0) to exit MMIO address
.global _exit
.type _exit, @function
_exit:
    li t0, 0x0000FFF4
    sw a0, 0(t0)

.L_dead_loop:
    j .L_dead_loop

.size _start, . - _start
