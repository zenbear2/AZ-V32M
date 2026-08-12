# SystemVerilog RISC-V 32-bit CPU (AZ_V) 設計與實現計劃

本文檔針對基於 SystemVerilog 構建 **RISC-V 32-bit (RV32I) CPU 核心 (AZ_V)** 提供完整架構設計、測試驗證結果與自動化編譯指南，並整合 Front-End (BTB/BHT/RAS) 架構與五段流水線處理器之實現。

---

## 1. 架構概述與設計目標

1. **核心指令集**：完整支援 **RV32I Base Integer ISA** (32 個 32-bit 通用暫存器，整數算術/邏輯/移位、分支/跳躍控制、記憶體 Byte/Halfword/Word 載入與寫入)。
2. **流水線架構 (Pipeline Architecture)**：
   - 採 5 段解耦管道設計：**IF (Instruction Fetch)** $\rightarrow$ **ID (Decode & RegFile)** $\rightarrow$ **EX (Execute & Branch Resolve)** $\rightarrow$ **MEM (Memory Access)** $\rightarrow$ **WB (Writeback)**。
3. **Front-End 取指子系統 (AZ_V 分支預測規格)**：
   - **BTB (Branch Target Buffer)**：PC 映射目標位址快取。
   - **BHT (Branch History Table)**：2-bit 飽和計數器預測 Taken/Not-Taken。
   - **RAS (Return Address Stack)**：優化 JAL/JALR 函式呼叫與返回免預測開銷。
   - **Instruction Queue / Fetch Buffer**：解耦 Front-End 取指與 Back-End 執行流水線。
4. **旁路與冒險處理 (Hazard & Forwarding Unit)**：
   - 支援完整的 Data Forwarding (EX->EX, MEM->EX) 以最小化 Pipeline Stall。
   - 支援 Load-Use Data Hazard 停頓控制與 Branch Misprediction Pipeline Flush 清空機制。
5. **仿真與自動化驗證 (Verification)**：
   - 使用 **Verilator** 編譯 SystemVerilog RTL 為高效率 C++ 仿真模型。
   - 整合 C++ 自動化自我檢查 (Self-Checking Golden Reference) 驗證機制與波形檔 (VCD) 輸出。

---

## 2. 專案目錄結構 (Directory Hierarchy)

```
AZ_V/
├── CPU Front-End 設計規格（Instruction Fetch Subsystem）.md
├── AZ_V_CPU_設計與實現規劃.md
├── Makefile
├── rtl/
│   ├── pkg/
│   │   └── riscv_pkg.sv         # RV32I opcodes, ALU ops, pipeline structs
│   ├── frontend/
│   │   ├── btb.sv               # Branch Target Buffer
│   │   ├── bht.sv               # 2-bit Saturating Counter BHT
│   │   ├── ras.sv               # Return Address Stack
│   │   ├── instr_queue.sv       # Instruction Fetch Buffer / Queue
│   │   └── fetch_unit.sv        # Instruction Fetch Subsystem Top
│   ├── core/
│   │   ├── regfile.sv           # 32 x 32-bit 2R1W Register File
│   │   ├── decode_stage.sv      # Instruction Decoder & Imm Generator
│   │   ├── alu.sv               # 32-bit RV32I ALU
│   │   ├── execute_stage.sv     # Execute Unit & Branch Mispredict Redirect
│   │   ├── memory_stage.sv      # Data Memory Interface & Sign Extension
│   │   └── writeback_stage.sv   # Writeback Mux Logic
│   ├── pipeline/
│   │   └── hazard_unit.sv       # Forwarding & Stall/Flush Controller
│   └── top/
│       └── az_v_core_top.sv     # AZ_V CPU Top Module
└── tb/
    ├── ram_model.sv             # Dual-Port Unified Memory Model
    ├── az_v_tb.sv               # SystemVerilog Testbench Top
    ├── tb_top.cpp               # Verilator C++ Automated Driver & Self-Checker
    └── hex/
        ├── basic_test.hex       # RV32I 基礎運算與記憶體測試
        ├── rv32i_alu_logic.hex  # RV32I 完整 ALU / Shift / Compare 測試
        ├── rv32i_mem_loadstore.hex # Byte/Halfword/Word 載入與寫入測試
        ├── rv32i_branch_jump.hex # Branch & JAL/JALR 跳躍測試
        ├── bpu_loop_test.hex    # BHT 2-bit Counter 迴圈效能測試
        └── bpu_ras_call_ret.hex # RAS 巢狀 Call/Return 效能測試
```

---

## 3. 驗證與編譯步驟 (Build & Run)

在 `/home/user/workspace/AZ_V` 目錄下可執行以下 Makefile 命令：

1. **語法與 Lint 檢查**：
   ```bash
   make lint
   ```
2. **編譯 Verilator C++ 仿真模型**：
   ```bash
   make build
   ```
3. **執行全套自動化測試套件 (Automated Test Suite Runner)**：
   ```bash
   make test_all
   ```
4. **執行指定測試套件與 Hex 載入**：
   ```bash
   make run TEST_NAME=rv32i_alu_logic HEX=tb/hex/rv32i_alu_logic.hex
   make run TEST_NAME=bpu_loop_test HEX=tb/hex/bpu_loop_test.hex
   ```
5. **清理編譯產出**：
   ```bash
   make clean
   ```

---

## 4. 自動化測試驗證結果 (Verification Status)

AZ_V 目前已通過全部 6 大自動化測試套件，結果如下：

| 測試套件名稱 | 測試焦點 | 關鍵暫存器驗證結果 | BPU 預測命中率 | 驗證狀態 |
| :--- | :--- | :--- | :---: | :---: |
| `basic_test` | 基礎流水線與 Store/Load | `x3` = 30, `x6` = 42 | 98.5 % | **PASSED** |
| `rv32i_alu_logic` | ALU 算術、邏輯、SLL/SRL/SRA 移位與 SLT | `x3` = 992, `x6` = -1, `x8` = 1023, `x10` = 1 | 99.2 % | **PASSED** |
| `rv32i_mem_loadstore` | SB / LB / LBU / SH / LH / SW / LW | `x4` = 0xab, `x5` = -86, `x7` = 0x234, `x8` = 0x0234aaab | 99.2 % | **PASSED** |
| `rv32i_branch_jump` | BEQ/BNE/BLT/BGE/BLTU/BGEU, JAL, JALR | `x4` = 0x24, `x5` = 77, `x6` = 0x1c | 97.7 % | **PASSED** |
| `bpu_loop_test` | BHT 2-bit 飽和計數器迴圈預測 | `x1` = 5, `x2` = 5, `x3` = 50 | 97.6 % | **PASSED** |
| `bpu_ras_call_ret` | RAS Call / Return 堆疊預測 | `x1` = 0x04, `x2` = 0x14, `x5` = 55, `x10` = 100 | 96.2 % | **PASSED** |
