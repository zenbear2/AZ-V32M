/* ============================================================================
 * File: matrix_mul.c
 * Description: 3x3 Matrix Multiplication Test for AZ_V CPU
 * Project: AZ_V RISC-V CPU
 * ============================================================================
 */

#include "az_v.h"

#define N 3

int main() {
    print_str("==========================================\n");
    print_str(" Running Matrix Multiplication on AZ_V...\n");
    print_str("==========================================\n");

    int A[N][N] = {
        {1, 2, 3},
        {4, 5, 6},
        {7, 8, 9}
    };

    int B[N][N] = {
        {9, 8, 7},
        {6, 5, 4},
        {3, 2, 1}
    };

    int C[N][N] = {0};

    int expected[N][N] = {
        {30,  24,  18},
        {84,  69,  54},
        {138, 114, 90}
    };

    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            C[i][j] = 0;
            for (int k = 0; k < N; k++) {
                C[i][j] += A[i][k] * B[k][j];
            }
        }
    }

    int pass = 1;
    print_str("Result Matrix C:\n");
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            print_dec(C[i][j]);
            print_str("\t");
            if (C[i][j] != expected[i][j]) {
                pass = 0;
            }
        }
        print_str("\n");
    }

    if (pass) {
        print_str(">>> Matrix Multiplication Test: PASSED <<<\n");
        return 0;
    } else {
        print_str(">>> Matrix Multiplication Test: FAILED <<<\n");
        return 1;
    }
}
