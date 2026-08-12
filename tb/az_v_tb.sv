// ============================================================================
// File: az_v_tb.sv
// Description: Top-Level SystemVerilog Testbench for Verilator
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module az_v_tb #(
  parameter string HEX_FILE = "tb/hex/basic_test.hex"
)(
  input logic clk,
  input logic rst_n
);

  // Interconnect Signals
  logic [31:0] imem_addr;
  logic [31:0] imem_rdata;

  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [3:0]  dmem_byte_enable;
  logic        dmem_req;
  logic        dmem_we;
  logic [31:0] dmem_rdata;

  // Instantiate CPU Core Top
  az_v_core_top u_core (
    .clk              (clk),
    .rst_n            (rst_n),
    .imem_addr        (imem_addr),
    .imem_rdata        (imem_rdata),
    .dmem_addr        (dmem_addr),
    .dmem_wdata       (dmem_wdata),
    .dmem_byte_enable (dmem_byte_enable),
    .dmem_req         (dmem_req),
    .dmem_we          (dmem_we),
    .dmem_rdata       (dmem_rdata)
  );

  // Instantiate Memory Model
  ram_model #(
    .MEM_SIZE_BYTES (65536),
    .HEX_FILE       (HEX_FILE)
  ) u_ram (
    .clk              (clk),
    .imem_addr        (imem_addr),
    .imem_rdata        (imem_rdata),
    .dmem_addr        (dmem_addr),
    .dmem_wdata       (dmem_wdata),
    .dmem_byte_enable (dmem_byte_enable),
    .dmem_req         (dmem_req),
    .dmem_we          (dmem_we),
    .dmem_rdata       (dmem_rdata)
  );

endmodule
