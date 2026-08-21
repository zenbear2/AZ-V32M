// ============================================================================
// File: regfile.sv
// Description: 32 x 32-bit General Purpose Register File (2R1W)
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module regfile (
  input  logic        clk,
  input  logic        rst_n,

  // Read Port 1
  input  logic [4:0]  raddr1,
  output logic [31:0] rdata1,

  // Read Port 2
  input  logic [4:0]  raddr2,
  output logic [31:0] rdata2,

  // Write Port
  input  logic        wen,
  input  logic [4:0]  waddr,
  input  logic [31:0] wdata,

  // Debug Read & Write Ports
  input  logic [4:0]  debug_raddr,
  output logic [31:0] debug_rdata,
  input  logic        debug_wen,
  input  logic [4:0]  debug_waddr,
  input  logic [31:0] debug_wdata
);

  logic [31:0] regs [31:1];

  // Asynchronous Read
  always_comb begin
    if (raddr1 == 5'd0) begin
      rdata1 = 32'd0;
    end else begin
      rdata1 = regs[raddr1];
    end
  end

  always_comb begin
    if (raddr2 == 5'd0) begin
      rdata2 = 32'd0;
    end else begin
      rdata2 = regs[raddr2];
    end
  end

  // Debug Read Port
  always_comb begin
    if (debug_raddr == 5'd0) begin
      debug_rdata = 32'd0;
    end else if (debug_wen && (debug_waddr == debug_raddr)) begin
      debug_rdata = debug_wdata;
    end else begin
      debug_rdata = regs[debug_raddr];
    end
  end

  // Synchronous Write on Negative Clock Edge (Splits WB and ID into half-cycles)
  integer i;
  always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 1; i < 32; i = i + 1) begin
        regs[i] <= 32'd0;
      end
    end else if (debug_wen && (debug_waddr != 5'd0)) begin
      regs[debug_waddr] <= debug_wdata;
    end else if (wen && (waddr != 5'd0)) begin
      regs[waddr] <= wdata;
    end
  end

endmodule
