// ============================================================================
// File: ras.sv
// Description: Return Address Stack (RAS) Module for Function Calls/Returns
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module ras #(
  parameter int DEPTH = 8,
  parameter int PTR_WIDTH = $clog2(DEPTH)
)(
  input  logic        clk,
  input  logic        rst_n,

  // Push / Pop Control (IF stage or Decode stage)
  input  logic        push_en,
  input  logic [31:0] push_addr,

  input  logic        pop_en,
  output logic [31:0] pop_target,
  output logic        empty
);

  logic [31:0] stack [DEPTH];
  logic [PTR_WIDTH:0] tos_ptr; // Top of stack pointer

  assign empty      = (tos_ptr == '0);
  assign pop_target = (empty) ? 32'h0 : stack[tos_ptr[PTR_WIDTH-1:0] - 1'b1];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tos_ptr <= '0;
    end else begin
      if (push_en && pop_en) begin
        // Simultaneous push and pop -> overwrite top entry
        if (tos_ptr > 0) begin
          stack[tos_ptr[PTR_WIDTH-1:0] - 1'b1] <= push_addr;
        end
      end else if (push_en) begin
        if (tos_ptr < (PTR_WIDTH+1)'(DEPTH)) begin
          stack[tos_ptr[PTR_WIDTH-1:0]] <= push_addr;
          tos_ptr                       <= tos_ptr + 1'b1;
        end else begin
          // Stack overflow: overwrite top entry
          stack[DEPTH-1] <= push_addr;
        end
      end else if (pop_en) begin
        if (tos_ptr > 0) begin
          tos_ptr <= tos_ptr - 1'b1;
        end
      end
    end
  end

endmodule
