/* ============================================================================
 * File: bubble_sort.c
 * Description: Memory load/store and array bubble sort test for AZ_V CPU
 * Project: AZ_V RISC-V CPU
 * ============================================================================
 */

#include "az_v.h"

void bubble_sort(int arr[], int n) {
    for (int i = 0; i < n - 1; i++) {
        for (int j = 0; j < n - i - 1; j++) {
            if (arr[j] > arr[j + 1]) {
                int temp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = temp;
            }
        }
    }
}

int main() {
    print_str("==========================================\n");
    print_str(" Running Bubble Sort Test on AZ_V CPU...\n");
    print_str("==========================================\n");

    int data[8] = {64, 34, 25, 12, 22, 11, 90, 1};
    int expected[8] = {1, 11, 12, 22, 25, 34, 64, 90};

    print_str("Original Array: ");
    for (int i = 0; i < 8; i++) {
        print_dec(data[i]);
        print_str(" ");
    }
    print_str("\n");

    bubble_sort(data, 8);

    print_str("Sorted Array:   ");
    for (int i = 0; i < 8; i++) {
        print_dec(data[i]);
        print_str(" ");
    }
    print_str("\n");

    int pass = 1;
    for (int i = 0; i < 8; i++) {
        if (data[i] != expected[i]) {
            pass = 0;
            break;
        }
    }

    if (pass) {
        print_str(">>> Bubble Sort Test: PASSED <<<\n");
        return 0;
    } else {
        print_str(">>> Bubble Sort Test: FAILED <<<\n");
        return 1;
    }
}
