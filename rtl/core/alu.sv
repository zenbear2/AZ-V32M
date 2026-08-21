// ============================================================================
// File: alu.sv
// Description: RV32I Arithmetic Logic Unit (ALU) - Timing Optimized Adder/Comparator Sharing
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module alu (
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  alu_op_e     alu_op,
  output logic [31:0] result,
  output logic        zero
);

  logic [31:0] adder_b;
  logic [31:0] adder_res;
  logic        adder_sub;
  logic        slt_res;
  logic        sltu_res;
  logic [32:0] sum_extended;

  assign adder_sub    = (alu_op == ALU_SUB || alu_op == ALU_SLT || alu_op == ALU_SLTU);
  assign adder_b      = adder_sub ? ~b : b;
  assign sum_extended = {1'b0, a} + {1'b0, adder_b} + {32'd0, adder_sub};
  assign adder_res    = sum_extended[31:0];
  assign sltu_res     = ~sum_extended[32]; // For unsigned a - b: inverted carry out indicates a < b
  assign slt_res      = (a[31] ^ b[31]) ? a[31] : adder_res[31];

  always_comb begin
    case (alu_op)
      ALU_ADD,
      ALU_SUB:    result = adder_res;
      ALU_SLL:    result = a << b[4:0];
      ALU_SLT:    result = {31'd0, slt_res};
      ALU_SLTU:   result = {31'd0, sltu_res};
      ALU_XOR:    result = a ^ b;
      ALU_SRL:    result = a >> b[4:0];
      ALU_SRA:    result = $signed(a) >>> b[4:0];
      ALU_OR:     result = a | b;
      ALU_AND:    result = a & b;
      ALU_PASS_B: result = b;
      default:    result = 32'd0;
    endcase
  end

  assign zero = (result == 32'd0);

endmodule
