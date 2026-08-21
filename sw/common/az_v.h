/* ============================================================================
 * File: az_v.h
 * Description: Bare-metal helper functions and MMIO addresses for AZ_V CPU
 * Project: AZ_V RISC-V CPU
 * ============================================================================
 */

#ifndef AZ_V_H
#define AZ_V_H

#define MMIO_STDOUT_ADDR 0x0000FFF0
#define MMIO_EXIT_ADDR   0x0000FFF4

#define MMIO_STDOUT (*(volatile unsigned int *)MMIO_STDOUT_ADDR)
#define MMIO_EXIT   (*(volatile unsigned int *)MMIO_EXIT_ADDR)

void putchar(char c);
void print_str(const char *str);
void print_dec(int val);
void print_hex(unsigned int val);
void az_v_exit(int status);

#endif // AZ_V_H
