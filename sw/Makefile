# ============================================================================
# Makefile for AZ_V Bare-Metal C Programs
# Project: AZ_V RISC-V CPU
# ============================================================================

# Auto-detect RISC-V Toolchain Compiler
GCC_BIN ?= $(shell which riscv64-unknown-elf-gcc 2>/dev/null || \
                   which riscv32-unknown-elf-gcc 2>/dev/null || \
                   which riscv-none-elf-gcc 2>/dev/null || \
                   echo /home/user/miniconda3/pkgs/riscv-tools-1.0.6-0_h1234567_g56c29e0/riscv-tools/bin/riscv64-unknown-elf-gcc)

PREFIX  ?= $(dir $(GCC_BIN))riscv64-unknown-elf-

CC      = $(GCC_BIN)
OBJCOPY = $(dir $(GCC_BIN))riscv64-unknown-elf-objcopy
OBJDUMP = $(dir $(GCC_BIN))riscv64-unknown-elf-objdump
PYTHON  = python3

CFLAGS  = -march=rv32i -mabi=ilp32 -O2 -nostdlib -ffreestanding -Wall -Icommon
LDFLAGS = -T common/link.ld

COMMON_SRCS = common/crt0.s common/az_v.c
EXAMPLES    = hello fibonacci bubble_sort matrix_mul

HEX_DIR     = build

.PHONY: all clean $(EXAMPLES)

all: $(EXAMPLES)

$(EXAMPLES): %: $(HEX_DIR)/%.hex

$(HEX_DIR):
	mkdir -p $(HEX_DIR)

$(HEX_DIR)/%.elf: examples/%.c $(COMMON_SRCS) common/link.ld | $(HEX_DIR)
	@echo "[Compiling C Program: $<]"
	$(CC) $(CFLAGS) $(LDFLAGS) $(COMMON_SRCS) $< -o $@
	$(OBJDUMP) -D -S $@ > $(HEX_DIR)/$*.dis

$(HEX_DIR)/%.bin: $(HEX_DIR)/%.elf
	$(OBJCOPY) -O binary $< $@

$(HEX_DIR)/%.hex: $(HEX_DIR)/%.bin tools/elf2hex.py
	@echo "[Generating Hex Preload: $@]"
	$(PYTHON) tools/elf2hex.py $< $@ --pad 65536

clean:
	rm -rf $(HEX_DIR)
