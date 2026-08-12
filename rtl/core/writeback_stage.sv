// ============================================================================
// File: writeback_stage.sv
// Description: Writeback Stage Mux Logic
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module writeback_stage (
  input  mem_wb_reg_t mem_wb_in,
  output logic [31:0] wb_wdata,
  output logic [4:0]  wb_rd,
  output logic        wb_reg_write
);

  assign wb_rd        = mem_wb_in.rd;
  assign wb_reg_write = mem_wb_in.valid && mem_wb_in.reg_write;

  always_comb begin
    case (mem_wb_in.wb_src)
      WB_ALU:  wb_wdata = mem_wb_in.alu_result;
      WB_MEM:  wb_wdata = mem_wb_in.mem_rdata;
      WB_PC4:  wb_wdata = mem_wb_in.pc_plus4;
      default: wb_wdata = mem_wb_in.alu_result;
    endcase
  end

endmodule
