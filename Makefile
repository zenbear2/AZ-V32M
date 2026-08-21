# ============================================================================
# Makefile for AZ_V SystemVerilog RISC-V CPU
# ============================================================================

RTL_PKG    = rtl/pkg/riscv_pkg.sv
RTL_FRONT  = rtl/frontend/btb.sv \
             rtl/frontend/bht.sv \
             rtl/frontend/ras.sv \
             rtl/frontend/instr_queue.sv \
             rtl/frontend/fetch_unit.sv

RTL_CORE   = rtl/core/regfile.sv \
             rtl/core/decode_stage.sv \
             rtl/core/alu.sv \
             rtl/core/execute_stage.sv \
             rtl/core/memory_stage.sv \
             rtl/core/writeback_stage.sv

RTL_PIPE   = rtl/pipeline/hazard_unit.sv
RTL_TOP    = rtl/top/az_v_core_top.sv

RTL_SRCS   = $(RTL_PKG) $(RTL_FRONT) $(RTL_CORE) $(RTL_PIPE) $(RTL_TOP)
TB_SRCS    = tb/ram_model.sv tb/az_v_tb.sv
CPP_TB     = tb/tb_top.cpp

VERILATOR  = verilator
VFLAGS     = -Wall -Wno-IMPORTSTAR -Wno-UNUSED -Wno-PINMISSING -Wno-PINCONNECTEMPTY --trace --cc -Irtl/pkg -Irtl/frontend -Irtl/core -Irtl/pipeline -Irtl/top

HEX        ?= tb/hex/basic_test.hex
TEST_NAME  ?= basic_test
MAX_CYCLES ?= 150

.PHONY: all lint build build_sw run run_c test_all test_c_all clean

all: build build_sw test_all test_c_all

lint:
	@echo "[Running Verilator Lint]"
	$(VERILATOR) --lint-only $(VFLAGS) $(RTL_SRCS) $(TB_SRCS) --top-module az_v_tb

build:
	@echo "[Building Verilator Simulation C++ Executable]"
	$(VERILATOR) $(VFLAGS) --exe --build -j 4 $(RTL_SRCS) $(TB_SRCS) $(CPP_TB) --top-module az_v_tb -o Vaz_v_tb

build_sw:
	@echo "[Building Bare-Metal C Software Programs with RISC-V GCC]"
	@$(MAKE) -C sw all

run:
	@echo "[Running AZ_V Simulation: $(TEST_NAME)]"
	./obj_dir/Vaz_v_tb +HEX=$(HEX) +TEST_NAME=$(TEST_NAME) +MAX_CYCLES=$(MAX_CYCLES)

run_c: build build_sw
	@echo "[Running AZ_V C Program: $(TEST_NAME)]"
	./obj_dir/Vaz_v_tb +HEX=sw/build/$(TEST_NAME).hex +TEST_NAME=$(TEST_NAME) +MAX_CYCLES=100000

test_c_all: build build_sw
	@echo "=========================================================================="
	@echo "            AZ_V RISC-V Bare-Metal C Program Test Suite                  "
	@echo "=========================================================================="
	@./obj_dir/Vaz_v_tb +HEX=sw/build/hello.hex +TEST_NAME=hello_c +MAX_CYCLES=100000
	@./obj_dir/Vaz_v_tb +HEX=sw/build/fibonacci.hex +TEST_NAME=fibonacci_c +MAX_CYCLES=100000
	@./obj_dir/Vaz_v_tb +HEX=sw/build/bubble_sort.hex +TEST_NAME=bubble_sort_c +MAX_CYCLES=100000
	@./obj_dir/Vaz_v_tb +HEX=sw/build/matrix_mul.hex +TEST_NAME=matrix_mul_c +MAX_CYCLES=100000
	@echo "=========================================================================="
	@echo "         ALL BARE-METAL C PROGRAM TESTS COMPLETED SUCCESSFULLY!          "
	@echo "=========================================================================="

test_all: build
	@echo "=========================================================================="
	@echo "               AZ_V RISC-V Automated Test Suite Runner                  "
	@echo "=========================================================================="
	@./obj_dir/Vaz_v_tb +HEX=tb/hex/basic_test.hex +TEST_NAME=basic_test
	@./obj_dir/Vaz_v_tb +HEX=tb/hex/rv32i_alu_logic.hex +TEST_NAME=rv32i_alu_logic
	@./obj_dir/Vaz_v_tb +HEX=tb/hex/rv32i_mem_loadstore.hex +TEST_NAME=rv32i_mem_loadstore
	@./obj_dir/Vaz_v_tb +HEX=tb/hex/rv32i_branch_jump.hex +TEST_NAME=rv32i_branch_jump
	@./obj_dir/Vaz_v_tb +HEX=tb/hex/bpu_loop_test.hex +TEST_NAME=bpu_loop_test
	@./obj_dir/Vaz_v_tb +HEX=tb/hex/bpu_ras_call_ret.hex +TEST_NAME=bpu_ras_call_ret
	@echo "=========================================================================="
	@echo "               ALL AZ_V TEST SUITES COMPLETED SUCCESSFULLY!              "
	@echo "=========================================================================="

clean:
	@echo "[Cleaning Built Artifacts]"
	rm -rf obj_dir sim_wave.vcd
	@$(MAKE) -C sw clean
