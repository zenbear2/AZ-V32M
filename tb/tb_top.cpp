// ============================================================================
// File: tb_top.cpp
// Description: Verilator C++ Automated Self-Checking Driver & BPU Profiler
// Project: AZ_V RISC-V CPU
// ============================================================================

#include <iostream>
#include <iomanip>
#include <memory>
#include <map>
#include <string>
#include "Vaz_v_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

struct GoldenRegs {
    std::map<int, uint32_t> regs;
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    auto top = std::make_unique<Vaz_v_tb>();
    auto tfp = std::make_unique<VerilatedVcdC>();

    // Parse argument options
    const char* test_name_arg = Verilated::commandArgsPlusMatch("TEST_NAME=");
    std::string test_name = "AZ_V Test";
    if (test_name_arg && test_name_arg[0] != '\0') {
        test_name = std::string(test_name_arg + 11);
    }

    const char* hex_file_arg = Verilated::commandArgsPlusMatch("HEX=");
    std::string hex_file = "tb/hex/basic_test.hex";
    if (hex_file_arg && hex_file_arg[0] != '\0') {
        hex_file = std::string(hex_file_arg + 5);
    }

    top->trace(tfp.get(), 99);
    tfp->open("sim_wave.vcd");

    vluint64_t main_time = 0;
    top->clk = 0;
    top->rst_n = 0;

    // Performance & Profiling Counters
    uint32_t total_branches = 0;
    uint32_t branch_hits = 0;
    uint32_t branch_mispredicts = 0;
    uint32_t total_flushes = 0;
    uint32_t total_cycles = 0;

    std::cout << "\n==========================================" << std::endl;
    std::cout << " Running Suite: " << test_name << std::endl;
    std::cout << " Hex Image:    " << hex_file << std::endl;
    std::cout << "==========================================" << std::endl;

    // Simulation loop
    int max_cycles = 150;
    for (int cycle = 0; cycle < max_cycles; cycle++) {
        total_cycles = cycle;
        if (cycle < 5) {
            top->rst_n = 0;
        } else {
            top->rst_n = 1;
        }

        // Toggle Clock (Low)
        top->clk = 0;
        top->eval();
        tfp->dump(main_time);
        main_time += 5;

        // BPU & Hazard Monitoring on clock rising edge
        if (top->rst_n) {
            if (top->az_v_tb__DOT__u_core__DOT__bpu_update_en) {
                total_branches++;
                if (top->az_v_tb__DOT__u_core__DOT__mispredict) {
                    branch_mispredicts++;
                    total_flushes++;
                } else {
                    branch_hits++;
                }
            }
        }

        // Toggle Clock (High)
        top->clk = 1;
        top->eval();
        tfp->dump(main_time);
        main_time += 5;


    }

    tfp->close();

    // Golden Expected Register Maps for known tests
    std::map<std::string, GoldenRegs> golden_suite = {
        {"basic_test", {{{1, 10}, {2, 20}, {3, 30}, {4, 10}, {5, 30}, {6, 42}}}},
        {"rv32i_alu_logic", {{{1, 31}, {2, 5}, {3, 992}, {4, 31}, {5, 0xfffffff6}, {6, 0xffffffff}, {7, 0}, {8, 1023}, {9, 992}, {10, 1}, {11, 0}}}},
        {"rv32i_mem_loadstore", {{{1, 256}, {2, 0xab}, {3, 0xffffffaa}, {4, 0xab}, {5, 0xffffffaa}, {6, 0x234}, {7, 0x234}, {8, 0x0234aaab}}}},
        {"rv32i_branch_jump", {{{1, 10}, {2, 20}, {3, 0}, {4, 36}, {5, 77}, {6, 28}}}},
        {"bpu_loop_test", {{{1, 5}, {2, 5}, {3, 50}}}},
        {"bpu_ras_call_ret", {{{1, 4}, {2, 20}, {5, 55}, {10, 100}}}}
    };

    std::cout << "\n------------------------------------------" << std::endl;
    std::cout << "        AZ_V Register File Dump          " << std::endl;
    std::cout << "------------------------------------------" << std::endl;
    for (int i = 1; i <= 11; i++) {
        uint32_t val = top->az_v_tb__DOT__u_core__DOT__u_decode_stage__DOT__u_regfile__DOT__regs[i-1];
        if (val != 0 || (golden_suite.count(test_name) && golden_suite[test_name].regs.count(i))) {
            std::cout << "x" << std::setw(2) << std::setfill('0') << i 
                      << " = 0x" << std::hex << std::setw(8) << std::setfill('0') << val
                      << " (" << std::dec << (int32_t)val << ")"
                      << std::endl;
        }
    }

    std::cout << "\n------------------------------------------" << std::endl;
    std::cout << "  Front-End BPU & Performance Statistics " << std::endl;
    std::cout << "------------------------------------------" << std::endl;
    std::cout << "Total Resolved Branches: " << total_branches << std::endl;
    std::cout << "Branch Hits (Correct)  : " << branch_hits << std::endl;
    std::cout << "Branch Mispredictions  : " << branch_mispredicts << std::endl;
    double hit_rate = (total_branches > 0) ? ((double)branch_hits / total_branches * 100.0) : 100.0;
    std::cout << "Branch Hit Accuracy    : " << std::fixed << std::setprecision(1) << hit_rate << " %" << std::endl;
    std::cout << "Pipeline Flush Cycles  : " << total_flushes << std::endl;

    // Check Self-Checking Verification
    bool pass = true;
    if (golden_suite.count(test_name)) {
        for (auto const& [reg_idx, expected_val] : golden_suite[test_name].regs) {
            uint32_t actual_val = top->az_v_tb__DOT__u_core__DOT__u_decode_stage__DOT__u_regfile__DOT__regs[reg_idx - 1];
            if (actual_val != expected_val) {
                std::cout << "[ERROR] Mismatch at x" << std::dec << reg_idx 
                          << ": Expected 0x" << std::hex << expected_val 
                          << ", Actual 0x" << actual_val << std::endl;
                pass = false;
            }
        }
    }

    std::cout << "==========================================" << std::endl;
    if (pass) {
        std::cout << " TEST RESULT: [ PASSED ]" << std::endl;
        std::cout << "==========================================\n" << std::endl;
        return 0;
    } else {
        std::cout << " TEST RESULT: [ FAILED ]" << std::endl;
        std::cout << "==========================================\n" << std::endl;
        return 1;
    }
}
