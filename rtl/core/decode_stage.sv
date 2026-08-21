// ============================================================================
// File: decode_stage.sv
// Description: Instruction Decode Stage & Register File Interface
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module decode_stage (
  input  logic        clk,
  input  logic        rst_n,

  // Input from IF stage (or Fetch Buffer)
  input  if_id_reg_t  if_id_in,

  // Writeback Interface (from WB stage)
  input  logic        wb_reg_write,
  input  logic [4:0]  wb_rd,
  input  logic [31:0] wb_wdata,

  // Debug Regfile Interface
  input  logic [4:0]  debug_gpr_addr,
  output logic [31:0] debug_gpr_rdata,
  input  logic        debug_gpr_wen,
  input  logic [31:0] debug_gpr_wdata,

  // Output to EX stage
  output id_ex_reg_t  id_ex_out,
  output logic [31:0] rf_rdata1,
  output logic [31:0] rf_rdata2
);

  logic [31:0] inst;
  logic [6:0]  opcode;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic [4:0]  rs1, rs2, rd;
  logic [31:0] imm;

  assign inst   = if_id_in.inst;
  assign opcode = inst[6:0];
  assign funct3 = inst[14:12];
  assign funct7 = inst[31:25];
  assign rs1    = inst[19:15];
  assign rs2    = inst[24:20];
  assign rd     = inst[11:7];

  // Register File Instance
  regfile u_regfile (
    .clk         (clk),
    .rst_n       (rst_n),
    .raddr1      (rs1),
    .rdata1      (rf_rdata1),
    .raddr2      (rs2),
    .rdata2      (rf_rdata2),
    .wen         (wb_reg_write),
    .waddr       (wb_rd),
    .wdata       (wb_wdata),
    .debug_raddr (debug_gpr_addr),
    .debug_rdata (debug_gpr_rdata),
    .debug_wen   (debug_gpr_wen),
    .debug_waddr (debug_gpr_addr),
    .debug_wdata (debug_gpr_wdata)
  );

  // Immediate Decoding
  always_comb begin
    case (opcode)
      OPCODE_LOAD, OPCODE_OP_IMM, OPCODE_JALR: // I-type
        imm = {{20{inst[31]}}, inst[31:20]};
      OPCODE_STORE: // S-type
        imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
      OPCODE_BRANCH: // B-type
        imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
      OPCODE_LUI, OPCODE_AUIPC: // U-type
        imm = {inst[31:12], 12'b0};
      OPCODE_JAL: // J-type
        imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
      default:
        imm = 32'd0;
    endcase
  end

  // Control Signal Decoding
  always_comb begin
    // Default Signals
    id_ex_out.valid        = if_id_in.valid;
    id_ex_out.pc           = if_id_in.pc;
    id_ex_out.pc_plus4     = if_id_in.pc_plus4;
    id_ex_out.rs1_data     = rf_rdata1;
    id_ex_out.rs2_data     = rf_rdata2;
    id_ex_out.rs1          = rs1;
    id_ex_out.rs2          = rs2;
    id_ex_out.rd           = rd;
    id_ex_out.imm          = imm;
    id_ex_out.pred_info    = if_id_in.pred_info;

    id_ex_out.alu_op       = ALU_ADD;
    id_ex_out.alu_src_b    = ALU_SRC_REG;
    id_ex_out.alu_src_a_pc = 1'b0;
    id_ex_out.branch_type  = BRANCH_NONE;
    id_ex_out.is_jal       = 1'b0;
    id_ex_out.is_jalr      = 1'b0;
    id_ex_out.mem_read     = 1'b0;
    id_ex_out.mem_write    = 1'b0;
    id_ex_out.mem_width    = MEM_WORD;
    id_ex_out.reg_write    = 1'b0;
    id_ex_out.wb_src       = WB_ALU;

    if (if_id_in.valid) begin
      case (opcode)
        OPCODE_LUI: begin
          id_ex_out.reg_write = 1'b1;
          id_ex_out.alu_op    = ALU_PASS_B;
          id_ex_out.alu_src_b = ALU_SRC_IMM;
          id_ex_out.wb_src    = WB_ALU;
        end

        OPCODE_AUIPC: begin
          id_ex_out.reg_write    = 1'b1;
          id_ex_out.alu_src_a_pc = 1'b1;
          id_ex_out.alu_src_b    = ALU_SRC_IMM;
          id_ex_out.alu_op       = ALU_ADD;
          id_ex_out.wb_src       = WB_ALU;
        end

        OPCODE_JAL: begin
          id_ex_out.reg_write = 1'b1;
          id_ex_out.is_jal    = 1'b1;
          id_ex_out.wb_src    = WB_PC4;
        end

        OPCODE_JALR: begin
          id_ex_out.reg_write = 1'b1;
          id_ex_out.is_jalr   = 1'b1;
          id_ex_out.alu_src_b = ALU_SRC_IMM;
          id_ex_out.alu_op    = ALU_ADD;
          id_ex_out.wb_src    = WB_PC4;
        end

        OPCODE_BRANCH: begin
          id_ex_out.branch_type = branch_type_e'(funct3);
        end

        OPCODE_LOAD: begin
          id_ex_out.reg_write = 1'b1;
          id_ex_out.mem_read  = 1'b1;
          id_ex_out.alu_src_b = ALU_SRC_IMM;
          id_ex_out.alu_op    = ALU_ADD;
          id_ex_out.mem_width = mem_width_e'(funct3);
          id_ex_out.wb_src    = WB_MEM;
        end

        OPCODE_STORE: begin
          id_ex_out.mem_write = 1'b1;
          id_ex_out.alu_src_b = ALU_SRC_IMM;
          id_ex_out.alu_op    = ALU_ADD;
          id_ex_out.mem_width = mem_width_e'(funct3);
        end

        OPCODE_OP_IMM: begin
          id_ex_out.reg_write = 1'b1;
          id_ex_out.alu_src_b = ALU_SRC_IMM;
          id_ex_out.wb_src    = WB_ALU;
          case (funct3)
            3'b000: id_ex_out.alu_op = ALU_ADD;
            3'b001: id_ex_out.alu_op = ALU_SLL;
            3'b010: id_ex_out.alu_op = ALU_SLT;
            3'b011: id_ex_out.alu_op = ALU_SLTU;
            3'b100: id_ex_out.alu_op = ALU_XOR;
            3'b101: id_ex_out.alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
            3'b110: id_ex_out.alu_op = ALU_OR;
            3'b111: id_ex_out.alu_op = ALU_AND;
          endcase
        end

        OPCODE_OP: begin
          id_ex_out.reg_write = 1'b1;
          id_ex_out.alu_src_b = ALU_SRC_REG;
          id_ex_out.wb_src    = WB_ALU;
          case (funct3)
            3'b000: id_ex_out.alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
            3'b001: id_ex_out.alu_op = ALU_SLL;
            3'b010: id_ex_out.alu_op = ALU_SLT;
            3'b011: id_ex_out.alu_op = ALU_SLTU;
            3'b100: id_ex_out.alu_op = ALU_XOR;
            3'b101: id_ex_out.alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
            3'b110: id_ex_out.alu_op = ALU_OR;
            3'b111: id_ex_out.alu_op = ALU_AND;
          endcase
        end

        default: ;
      endcase
    end
  end

endmodule
