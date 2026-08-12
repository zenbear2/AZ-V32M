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
  input  logic [31:0] wdata
);

  logic [31:0] regs [31:1];

  // Asynchronous Read with internal write-through forwarding
  always_comb begin
    if (raddr1 == 5'd0) begin
      rdata1 = 32'd0;
    end else if (wen && (waddr == raddr1)) begin
      rdata1 = wdata;
    end else begin
      rdata1 = regs[raddr1];
    end
  end

  always_comb begin
    if (raddr2 == 5'd0) begin
      rdata2 = 32'd0;
    end else if (wen && (waddr == raddr2)) begin
      rdata2 = wdata;
    end else begin
      rdata2 = regs[raddr2];
    end
  end

  // Synchronous Write
  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 1; i < 32; i = i + 1) begin
        regs[i] <= 32'd0;
      end
    end else if (wen && (waddr != 5'd0)) begin
      regs[waddr] <= wdata;
    end
  end

endmodule
