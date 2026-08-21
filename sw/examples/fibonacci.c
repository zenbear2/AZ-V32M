/* ============================================================================
 * File: fibonacci.c
 * Description: Fibonacci calculation test program for AZ_V CPU
 * Project: AZ_V RISC-V CPU
 * ============================================================================
 */

#include "az_v.h"

int fib(int n) {
    if (n <= 0) return 0;
    if (n == 1) return 1;
    return fib(n - 1) + fib(n - 2);
}

int main() {
    print_str("==========================================\n");
    print_str(" Running Fibonacci Test on AZ_V CPU...\n");
    print_str("==========================================\n");

    int expected[] = {0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55};
    int pass = 1;

    for (int i = 0; i <= 10; i++) {
        int res = fib(i);
        print_str("fib(");
        print_dec(i);
        print_str(") = ");
        print_dec(res);
        print_str("\n");

        if (res != expected[i]) {
            print_str("ERROR: Expected ");
            print_dec(expected[i]);
            print_str("\n");
            pass = 0;
        }
    }

    if (pass) {
        print_str(">>> Fibonacci Test: PASSED <<<\n");
        return 0;
    } else {
        print_str(">>> Fibonacci Test: FAILED <<<\n");
        return 1;
    }
}
