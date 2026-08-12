// ============================================================================
// File: bht.sv
// Description: Branch History Table (BHT) with 2-bit Saturating Counters
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module bht #(
  parameter int NUM_ENTRIES = 64,
  parameter int INDEX_WIDTH = $clog2(NUM_ENTRIES)
)(
  input  logic        clk,
  input  logic        rst_n,

  // Lookup Interface (IF stage)
  input  logic [31:0] fetch_pc,
  output logic        predict_taken,

  // Update Interface (EX stage resolution)
  input  logic        update_en,
  input  logic [31:0] update_pc,
  input  logic        actual_taken
);

  // 2-bit Saturating Counter States
  typedef enum logic [1:0] {
    STRONGLY_NOT_TAKEN = 2'b00,
    WEAKLY_NOT_TAKEN   = 2'b01,
    WEAKLY_TAKEN       = 2'b10,
    STRONGLY_TAKEN     = 2'b11
  } bht_state_e;

  logic [1:0] counters [NUM_ENTRIES];

  // Index Extraction
  logic [INDEX_WIDTH-1:0] fetch_index;
  logic [INDEX_WIDTH-1:0] update_index;

  assign fetch_index  = fetch_pc[INDEX_WIDTH+1 : 2];
  assign update_index = update_pc[INDEX_WIDTH+1 : 2];

  // Prediction: Taken if MSB is 1 (WEAKLY_TAKEN or STRONGLY_TAKEN)
  assign predict_taken = counters[fetch_index][1];

  // Update Logic (Sequential)
  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
        counters[i] <= WEAKLY_TAKEN; // Default predict weakly taken
      end
    end else if (update_en) begin
      if (actual_taken) begin
        if (counters[update_index] != STRONGLY_TAKEN) begin
          counters[update_index] <= counters[update_index] + 2'b01;
        end
      end else begin
        if (counters[update_index] != STRONGLY_NOT_TAKEN) begin
          counters[update_index] <= counters[update_index] - 2'b01;
        end
      end
    end
  end

endmodule
