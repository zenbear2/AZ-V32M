/* ============================================================================
 * File: az_v.c
 * Description: Bare-metal helper function implementations for AZ_V CPU
 * Project: AZ_V RISC-V CPU
 * ============================================================================
 */

#include "az_v.h"

void putchar(char c) {
    MMIO_STDOUT = (unsigned int)c;
}

void print_str(const char *str) {
    while (*str) {
        putchar(*str++);
    }
}

void print_hex(unsigned int val) {
    static const char hex_chars[] = "0123456789abcdef";
    print_str("0x");
    for (int i = 28; i >= 0; i -= 4) {
        putchar(hex_chars[(val >> i) & 0xF]);
    }
}

// ----------------------------------------------------------------------------
// Software Division, Modulo, and Multiplication for RV32I (No M extension)
// ----------------------------------------------------------------------------

static void udivmod32(unsigned int num, unsigned int den, unsigned int *quot, unsigned int *rem) {
    if (den == 0) {
        if (quot) *quot = 0;
        if (rem) *rem = 0;
        return;
    }
    unsigned int q = 0;
    unsigned int r = 0;
    for (int i = 31; i >= 0; i--) {
        r <<= 1;
        r |= (num >> i) & 1;
        if (r >= den) {
            r -= den;
            q |= (1U << i);
        }
    }
    if (quot) *quot = q;
    if (rem) *rem = r;
}

unsigned int __udivsi3(unsigned int a, unsigned int b) {
    unsigned int q;
    udivmod32(a, b, &q, 0);
    return q;
}

unsigned int __umodsi3(unsigned int a, unsigned int b) {
    unsigned int r;
    udivmod32(a, b, 0, &r);
    return r;
}

int __divsi3(int a, int b) {
    int neg = 0;
    if (a < 0) { a = -a; neg = !neg; }
    if (b < 0) { b = -b; neg = !neg; }
    unsigned int q;
    udivmod32((unsigned int)a, (unsigned int)b, &q, 0);
    return neg ? -(int)q : (int)q;
}

int __modsi3(int a, int b) {
    int neg = 0;
    if (a < 0) { a = -a; neg = 1; }
    if (b < 0) { b = -b; }
    unsigned int r;
    udivmod32((unsigned int)a, (unsigned int)b, 0, &r);
    return neg ? -(int)r : (int)r;
}

int __mulsi3(int a, int b) {
    int res = 0;
    unsigned int ua = (unsigned int)a;
    unsigned int ub = (unsigned int)b;
    while (ub > 0) {
        if (ub & 1) {
            res += ua;
        }
        ua <<= 1;
        ub >>= 1;
    }
    return res;
}

void print_dec(int val) {
    if (val == 0) {
        putchar('0');
        return;
    }
    if (val < 0) {
        putchar('-');
        val = -val;
    }
    char buf[12];
    int idx = 0;
    while (val > 0) {
        buf[idx++] = '0' + __modsi3(val, 10);
        val = __divsi3(val, 10);
    }
    for (int i = idx - 1; i >= 0; i--) {
        putchar(buf[i]);
    }
}

void az_v_exit(int status) {
    MMIO_EXIT = (unsigned int)status;
    while (1);
}
