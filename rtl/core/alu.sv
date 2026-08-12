// ============================================================================
// File: alu.sv
// Description: RV32I Arithmetic Logic Unit (ALU)
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

  always_comb begin
    case (alu_op)
      ALU_ADD:    result = a + b;
      ALU_SUB:    result = a - b;
      ALU_SLL:    result = a << b[4:0];
      ALU_SLT:    result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
      ALU_SLTU:   result = (a < b) ? 32'd1 : 32'd0;
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
