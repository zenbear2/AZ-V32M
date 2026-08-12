// ============================================================================
// File: instr_queue.sv
// Description: Instruction Queue / Fetch Buffer (FIFO)
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module instr_queue #(
  parameter int DEPTH = 8,
  parameter int PTR_WIDTH = $clog2(DEPTH)
)(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,

  // Write Interface (from IF)
  input  logic        push,
  input  if_id_reg_t  din,
  output logic        full,

  // Read Interface (to ID)
  input  logic        pop,
  output if_id_reg_t  dout,
  output logic        empty
);

  if_id_reg_t mem [DEPTH];

  logic [PTR_WIDTH-1:0] wr_ptr;
  logic [PTR_WIDTH-1:0] rd_ptr;
  logic [PTR_WIDTH:0]   count;

  assign full  = (count == DEPTH);
  assign empty = (count == 0);
  assign dout  = mem[rd_ptr];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      count  <= '0;
    end begin
      case ({push && !full, pop && !empty})
        2'b10: begin // Push only
          mem[wr_ptr] <= din;
          wr_ptr      <= wr_ptr + 1'b1;
          count       <= count + 1'b1;
        end
        2'b01: begin // Pop only
          rd_ptr <= rd_ptr + 1'b1;
          count  <= count - 1'b1;
        end
        2'b11: begin // Simultaneous Push and Pop
          mem[wr_ptr] <= din;
          wr_ptr      <= wr_ptr + 1'b1;
          rd_ptr      <= rd_ptr + 1'b1;
        end
        default: ;
      endcase
    end
  end

endmodule
