// ============================================================================
// File: fetch_unit.sv
// Description: Instruction Fetch Unit with BTB, BHT, and RAS Integration
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module fetch_unit (
  input  logic        clk,
  input  logic        rst_n,

  // Pipeline Stalls & Flushes
  input  logic        stall_if,
  input  logic        flush_if,

  // Branch Mispredict Redirect from EX stage
  input  logic        redirect_en,
  input  logic [31:0] redirect_target,

  // BHT/BTB Update Interface from EX stage
  input  logic        bpu_update_en,
  input  logic [31:0] bpu_update_pc,
  input  logic [31:0] bpu_update_target,
  input  logic        bpu_actual_taken,

  // Memory Interface (Instruction Memory / I-Cache)
  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,

  // Output to Decode Stage (IF/ID Register Interface)
  output if_id_reg_t  if_id_out
);

  logic [31:0] pc_reg, next_pc;

  // Predictor signals
  logic        btb_hit;
  logic [31:0] btb_target;
  logic        bht_predict_taken;
  branch_pred_t pred_info;

  // BTB Instance
  btb u_btb (
    .clk           (clk),
    .rst_n         (rst_n),
    .fetch_pc      (pc_reg),
    .hit           (btb_hit),
    .target_pc     (btb_target),
    .update_en     (bpu_update_en),
    .update_pc     (bpu_update_pc),
    .update_target (bpu_update_target)
  );

  // BHT Instance
  bht u_bht (
    .clk           (clk),
    .rst_n         (rst_n),
    .fetch_pc      (pc_reg),
    .predict_taken (bht_predict_taken),
    .update_en     (bpu_update_en),
    .update_pc     (bpu_update_pc),
    .actual_taken  (bpu_actual_taken)
  );

  // Quick Branch Target Prediction
  always_comb begin
    pred_info.valid       = btb_hit;
    pred_info.pred_taken  = btb_hit && bht_predict_taken;
    pred_info.pred_target = btb_target;
    pred_info.is_call     = 1'b0;
    pred_info.is_ret      = 1'b0;
  end

  // Next PC Mux (Priority: Redirect > Branch Predict > PC + 4)
  always_comb begin
    if (redirect_en) begin
      next_pc = redirect_target;
    end else if (pred_info.pred_taken) begin
      next_pc = pred_info.pred_target;
    end else begin
      next_pc = pc_reg + 32'd4;
    end
  end

  // PC Register Update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_reg <= BOOT_VECTOR;
    end else if (redirect_en) begin
      pc_reg <= redirect_target;
    end else if (!stall_if) begin
      pc_reg <= next_pc;
    end
  end

  // Memory Interface Assignment
  assign imem_addr = pc_reg;

  // Pipeline Output Packet Formulation
  always_comb begin
    if_id_out.valid     = !stall_if && !flush_if;
    if_id_out.pc        = pc_reg;
    if_id_out.pc_plus4  = pc_reg + 32'd4;
    if_id_out.inst      = imem_rdata;
    if_id_out.pred_info = pred_info;
  end

endmodule
