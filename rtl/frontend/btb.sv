// ============================================================================
// File: btb.sv
// Description: Branch Target Buffer (BTB) Module
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module btb #(
  parameter int NUM_ENTRIES = 64,
  parameter int INDEX_WIDTH = $clog2(NUM_ENTRIES), // 6 bits for 64 entries
  parameter int TAG_WIDTH   = 32 - 2 - INDEX_WIDTH // 24 bits for 32-bit PC
)(
  input  logic        clk,
  input  logic        rst_n,

  // Lookup Interface (IF stage)
  input  logic [31:0] fetch_pc,
  output logic        hit,
  output logic [31:0] target_pc,

  // Update Interface (EX stage resolution)
  input  logic        update_en,
  input  logic [31:0] update_pc,
  input  logic [31:0] update_target
);

  // BTB Entry Structure
  typedef struct packed {
    logic                 valid;
    logic [TAG_WIDTH-1:0] tag;
    logic [31:0]          target;
  } btb_entry_t;

  btb_entry_t entries [NUM_ENTRIES];

  // Index and Tag Extraction
  logic [INDEX_WIDTH-1:0] fetch_index;
  logic [TAG_WIDTH-1:0]   fetch_tag;

  logic [INDEX_WIDTH-1:0] update_index;
  logic [TAG_WIDTH-1:0]   update_tag;

  assign fetch_index  = fetch_pc[INDEX_WIDTH+1 : 2];
  assign fetch_tag    = fetch_pc[31 : INDEX_WIDTH+2];

  assign update_index = update_pc[INDEX_WIDTH+1 : 2];
  assign update_tag   = update_pc[31 : INDEX_WIDTH+2];

  // Lookup Logic (Combinational)
  always_comb begin
    if (entries[fetch_index].valid && (entries[fetch_index].tag == fetch_tag)) begin
      hit       = 1'b1;
      target_pc = entries[fetch_index].target;
    end else begin
      hit       = 1'b0;
      target_pc = fetch_pc + 32'd4;
    end
  end

  // Update Logic (Sequential)
  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
        entries[i].valid  <= 1'b0;
        entries[i].tag    <= '0;
        entries[i].target <= '0;
      end
    end else if (update_en) begin
      entries[update_index].valid  <= 1'b1;
      entries[update_index].tag    <= update_tag;
      entries[update_index].target <= update_target;
    end
  end

endmodule
