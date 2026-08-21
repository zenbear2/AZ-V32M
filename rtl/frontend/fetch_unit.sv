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

  // Debug PC Interface
  input  logic        debug_pc_wen,
  input  logic [31:0] debug_pc_wdata,
  output logic [31:0] debug_pc_rdata,

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

  // Instruction Pre-Decoder for RAS Call/Return Detection
  logic [6:0] fetch_opcode;
  logic [4:0] fetch_rd;
  logic [4:0] fetch_rs1;
  logic       is_call;
  logic       is_ret;

  assign fetch_opcode = imem_rdata[6:0];
  assign fetch_rd     = imem_rdata[11:7];
  assign fetch_rs1    = imem_rdata[19:15];

  assign is_call = (fetch_opcode == OPCODE_JAL || fetch_opcode == OPCODE_JALR) &&
                   (fetch_rd == 5'd1 || fetch_rd == 5'd5);

  assign is_ret  = (fetch_opcode == OPCODE_JALR) &&
                   (fetch_rs1 == 5'd1 || fetch_rs1 == 5'd5) &&
                   (fetch_rd != fetch_rs1);

  // RAS Signals & Instance
  logic        ras_push;
  logic [31:0] ras_push_addr;
  logic        ras_pop;
  logic [31:0] ras_pop_target;
  logic        ras_empty;

  assign ras_push      = is_call && if_id_out.valid;
  assign ras_push_addr = pc_reg + 32'd4;
  assign ras_pop       = is_ret && if_id_out.valid;

  ras #(
    .DEPTH(8)
  ) u_ras (
    .clk        (clk),
    .rst_n      (rst_n),
    .push_en    (ras_push),
    .push_addr  (ras_push_addr),
    .pop_en     (ras_pop),
    .pop_target (ras_pop_target),
    .empty      (ras_empty)
  );

  // Quick Branch & Return Target Prediction
  always_comb begin
    pred_info.valid       = btb_hit || is_ret;
    pred_info.is_call     = is_call;
    pred_info.is_ret      = is_ret;

    if (is_ret && !ras_empty) begin
      pred_info.pred_taken  = 1'b1;
      pred_info.pred_target = ras_pop_target;
    end else begin
      pred_info.pred_taken  = btb_hit && bht_predict_taken;
      pred_info.pred_target = btb_target;
    end
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
    end else if (debug_pc_wen) begin
      pc_reg <= debug_pc_wdata;
    end else if (redirect_en) begin
      pc_reg <= redirect_target;
    end else if (!stall_if) begin
      pc_reg <= next_pc;
    end
  end

  // Memory Interface & Debug PC Assignment
  assign imem_addr      = pc_reg;
  assign debug_pc_rdata = pc_reg;

  // Pipeline Output Packet Formulation
  always_comb begin
    if_id_out.valid     = !stall_if && !flush_if;
    if_id_out.pc        = pc_reg;
    if_id_out.pc_plus4  = pc_reg + 32'd4;
    if_id_out.inst      = imem_rdata;
    if_id_out.pred_info = pred_info;
  end

endmodule
