// ============================================================================
// File: riscv_pkg.sv
// Description: RISC-V 32-bit (RV32I) Architecture Package Definitions
// Project: AZ_V RISC-V CPU
// ============================================================================

package riscv_pkg;

  // --------------------------------------------------------------------------
  // Basic Data Types & System Constants
  // --------------------------------------------------------------------------
  localparam int XLEN = 32;
  localparam int INST_WIDTH = 32;
  localparam int REG_ADDR_WIDTH = 5;
  localparam int REG_NUM = 32;

  // Default Boot Vector
  localparam logic [XLEN-1:0] BOOT_VECTOR = 32'h0000_0000;

  // --------------------------------------------------------------------------
  // Opcodes (RISC-V Base RV32I)
  // --------------------------------------------------------------------------
  typedef enum logic [6:0] {
    OPCODE_LUI      = 7'b0110111,
    OPCODE_AUIPC    = 7'b0010111,
    OPCODE_JAL      = 7'b1101111,
    OPCODE_JALR     = 7'b1100111,
    OPCODE_BRANCH   = 7'b1100011,
    OPCODE_LOAD     = 7'b0000011,
    OPCODE_STORE    = 7'b0100011,
    OPCODE_OP_IMM   = 7'b0010011,
    OPCODE_OP       = 7'b0110011,
    OPCODE_SYSTEM   = 7'b1110011,
    OPCODE_MISC_MEM = 7'b0001111
  } opcode_e;

  // --------------------------------------------------------------------------
  // ALU Operation Codes
  // --------------------------------------------------------------------------
  typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_SLL  = 4'b0010,
    ALU_SLT  = 4'b0011,
    ALU_SLTU = 4'b0100,
    ALU_XOR  = 4'b0101,
    ALU_SRL  = 4'b0110,
    ALU_SRA  = 4'b0111,
    ALU_OR   = 4'b1000,
    ALU_AND  = 4'b1001,
    ALU_PASS_B = 4'b1010
  } alu_op_e;

  // --------------------------------------------------------------------------
  // Branch Types
  // --------------------------------------------------------------------------
  typedef enum logic [2:0] {
    BRANCH_BEQ  = 3'b000,
    BRANCH_BNE  = 3'b001,
    BRANCH_BLT  = 3'b100,
    BRANCH_BGE  = 3'b101,
    BRANCH_BLTU = 3'b110,
    BRANCH_BGEU = 3'b111,
    BRANCH_NONE = 3'b010
  } branch_type_e;

  // --------------------------------------------------------------------------
  // Memory Access Widths & Signedness
  // --------------------------------------------------------------------------
  typedef enum logic [2:0] {
    MEM_BYTE  = 3'b000,
    MEM_HALF  = 3'b001,
    MEM_WORD  = 3'b010,
    MEM_BYTEU = 3'b100,
    MEM_HALFU = 3'b101
  } mem_width_e;

  // --------------------------------------------------------------------------
  // Immediate Source Select
  // --------------------------------------------------------------------------
  typedef enum logic [2:0] {
    IMM_I = 3'b000,
    IMM_S = 3'b001,
    IMM_B = 3'b010,
    IMM_U = 3'b011,
    IMM_J = 3'b100
  } imm_src_e;

  // --------------------------------------------------------------------------
  // ALU Operand Mux Source Select
  // --------------------------------------------------------------------------
  typedef enum logic {
    ALU_SRC_REG = 1'b0,
    ALU_SRC_IMM = 1'b1
  } alu_src_b_e;

  // --------------------------------------------------------------------------
  // Writeback Mux Source Select
  // --------------------------------------------------------------------------
  typedef enum logic [1:0] {
    WB_ALU  = 2'b00,
    WB_MEM  = 2'b01,
    WB_PC4  = 2'b10
  } wb_src_e;

  // --------------------------------------------------------------------------
  // Branch Prediction Data Structure
  // --------------------------------------------------------------------------
  typedef struct packed {
    logic        valid;
    logic        pred_taken;
    logic [31:0] pred_target;
    logic        is_call;
    logic        is_ret;
  } branch_pred_t;

  // --------------------------------------------------------------------------
  // Pipeline Stage Structures
  // --------------------------------------------------------------------------

  // IF -> ID Pipeline Register
  typedef struct packed {
    logic        valid;
    logic [XLEN-1:0] pc;
    logic [XLEN-1:0] pc_plus4;
    logic [INST_WIDTH-1:0] inst;
    branch_pred_t    pred_info;
  } if_id_reg_t;

  // ID -> EX Pipeline Register
  typedef struct packed {
    logic        valid;
    logic [XLEN-1:0] pc;
    logic [XLEN-1:0] pc_plus4;
    logic [XLEN-1:0] rs1_data;
    logic [XLEN-1:0] rs2_data;
    logic [REG_ADDR_WIDTH-1:0] rs1;
    logic [REG_ADDR_WIDTH-1:0] rs2;
    logic [REG_ADDR_WIDTH-1:0] rd;
    logic [XLEN-1:0] imm;

    // Control Signals
    alu_op_e         alu_op;
    alu_src_b_e      alu_src_b;
    logic            alu_src_a_pc;
    branch_type_e    branch_type;
    logic            is_jal;
    logic            is_jalr;
    logic            mem_read;
    logic            mem_write;
    mem_width_e      mem_width;
    logic            reg_write;
    wb_src_e         wb_src;
    branch_pred_t    pred_info;
  } id_ex_reg_t;

  // EX -> MEM Pipeline Register
  typedef struct packed {
    logic        valid;
    logic [XLEN-1:0] pc;
    logic [XLEN-1:0] pc_plus4;
    logic [XLEN-1:0] alu_result;
    logic [XLEN-1:0] rs2_data;
    logic [REG_ADDR_WIDTH-1:0] rd;

    // Control Signals
    logic            mem_read;
    logic            mem_write;
    mem_width_e      mem_width;
    logic            reg_write;
    wb_src_e         wb_src;

    // BPU Update Signals (registered for timing optimization)
    logic            bpu_update_en;
    logic [XLEN-1:0] bpu_update_pc;
    logic [XLEN-1:0] bpu_update_target;
    logic            bpu_actual_taken;
  } ex_mem_reg_t;

  // MEM -> WB Pipeline Register
  typedef struct packed {
    logic        valid;
    logic [XLEN-1:0] pc_plus4;
    logic [XLEN-1:0] alu_result;
    logic [XLEN-1:0] mem_rdata;
    logic [REG_ADDR_WIDTH-1:0] rd;

    // Control Signals
    logic            reg_write;
    wb_src_e         wb_src;
  } mem_wb_reg_t;

endpackage: riscv_pkg
