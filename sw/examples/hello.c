/* ============================================================================
 * File: hello.c
 * Description: Hello World and Basic C Test Program for AZ_V CPU
 * Project: AZ_V RISC-V CPU
 * ============================================================================
 */

#include "az_v.h"

int main() {
    print_str("==========================================\n");
    print_str(" Hello World from AZ_V RISC-V CPU!\n");
    print_str(" Compiled with RISC-V GCC (RV32I)\n");
    print_str("==========================================\n");

    int a = 123;
    int b = 456;
    int sum = a + b;

    print_str("a = ");
    print_dec(a);
    print_str(", b = ");
    print_dec(b);
    print_str("\nSum a + b = ");
    print_dec(sum);
    print_str("\n");

    if (sum == 579) {
        print_str(">>> Hello C Test: PASSED <<<\n");
        return 0; // Success
    } else {
        print_str(">>> Hello C Test: FAILED <<<\n");
        return 1; // Failure
    }
}
