// ============================================================================
// File: az_v_core_top.sv
// Description: Top-Level Module for AZ_V RISC-V 32-bit CPU Core
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module az_v_core_top (
  input  logic        clk,
  input  logic        rst_n,

  // Instruction Memory Interface
  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,

  // Data Memory Interface
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_byte_enable,
  output logic        dmem_req,
  output logic        dmem_we,
  input  logic [31:0] dmem_rdata
);

  // --------------------------------------------------------------------------
  // Pipeline Registers & Interconnect Signals
  // --------------------------------------------------------------------------

  // Pipeline Control Signals (Stall & Flush)
  logic stall_if, stall_id;
  logic flush_if, flush_id, flush_ex;

  // Branch Mispredict Redirect Signals
  logic        mispredict;
  logic [31:0] redirect_target;

  // BPU Update Signals
  logic        bpu_update_en;
  logic [31:0] bpu_update_pc;
  logic [31:0] bpu_update_target;
  logic        bpu_actual_taken;

  // Forwarding Signals
  logic [1:0]  forward_a;
  logic [1:0]  forward_b;

  // Stage Packets
  if_id_reg_t  if_id_out, if_id_reg;

  id_ex_reg_t  id_ex_out, id_ex_reg;
  logic [31:0] rf_rdata1, rf_rdata2;

  ex_mem_reg_t ex_mem_out, ex_mem_reg;

  mem_wb_reg_t mem_wb_out, mem_wb_reg;

  // Writeback Stage Outputs
  logic [31:0] wb_wdata;
  logic [4:0]  wb_rd;
  logic        wb_reg_write;

  // --------------------------------------------------------------------------
  // IF Stage (Fetch Unit)
  // --------------------------------------------------------------------------
  fetch_unit u_fetch_unit (
    .clk               (clk),
    .rst_n             (rst_n),
    .stall_if          (stall_if),
    .flush_if          (flush_if),
    .redirect_en       (mispredict),
    .redirect_target   (redirect_target),
    .bpu_update_en     (bpu_update_en),
    .bpu_update_pc     (bpu_update_pc),
    .bpu_update_target (bpu_update_target),
    .bpu_actual_taken  (bpu_actual_taken),
    .imem_addr         (imem_addr),
    .imem_rdata        (imem_rdata),
    .if_id_out         (if_id_out)
  );

  // IF/ID Pipeline Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush_if) begin
      if_id_reg <= '0;
    end else if (!stall_id) begin
      if_id_reg <= if_id_out;
    end
  end

  // --------------------------------------------------------------------------
  // ID Stage (Decode Unit)
  // --------------------------------------------------------------------------
  decode_stage u_decode_stage (
    .clk          (clk),
    .rst_n        (rst_n),
    .if_id_in     (if_id_reg),
    .wb_reg_write (wb_reg_write),
    .wb_rd        (wb_rd),
    .wb_wdata     (wb_wdata),
    .id_ex_out    (id_ex_out),
    .rf_rdata1    (rf_rdata1),
    .rf_rdata2    (rf_rdata2)
  );

  // ID/EX Pipeline Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush_ex) begin
      id_ex_reg <= '0;
    end else begin
      id_ex_reg <= id_ex_out;
    end
  end

  // --------------------------------------------------------------------------
  // EX Stage (Execute Unit)
  // --------------------------------------------------------------------------
  execute_stage u_execute_stage (
    .id_ex_in          (id_ex_reg),
    .forward_a         (forward_a),
    .forward_b         (forward_b),
    .ex_mem_alu_result (ex_mem_reg.alu_result),
    .mem_wb_result     (wb_wdata),
    .mispredict        (mispredict),
    .redirect_target   (redirect_target),
    .bpu_update_en     (bpu_update_en),
    .bpu_update_pc     (bpu_update_pc),
    .bpu_update_target (bpu_update_target),
    .bpu_actual_taken  (bpu_actual_taken),
    .ex_mem_out        (ex_mem_out)
  );

  // EX/MEM Pipeline Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ex_mem_reg <= '0;
    end else begin
      ex_mem_reg <= ex_mem_out;
    end
  end

  // --------------------------------------------------------------------------
  // MEM Stage (Memory Unit)
  // --------------------------------------------------------------------------
  memory_stage u_memory_stage (
    .ex_mem_in        (ex_mem_reg),
    .dmem_addr        (dmem_addr),
    .dmem_wdata       (dmem_wdata),
    .dmem_byte_enable (dmem_byte_enable),
    .dmem_req         (dmem_req),
    .dmem_we          (dmem_we),
    .dmem_rdata       (dmem_rdata),
    .mem_wb_out       (mem_wb_out)
  );

  // MEM/WB Pipeline Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_wb_reg <= '0;
    end else begin
      mem_wb_reg <= mem_wb_out;
    end
  end

  // --------------------------------------------------------------------------
  // WB Stage (Writeback Unit)
  // --------------------------------------------------------------------------
  writeback_stage u_writeback_stage (
    .mem_wb_in    (mem_wb_reg),
    .wb_wdata     (wb_wdata),
    .wb_rd        (wb_rd),
    .wb_reg_write (wb_reg_write)
  );

  // --------------------------------------------------------------------------
  // Hazard Unit
  // --------------------------------------------------------------------------
  hazard_unit u_hazard_unit (
    .if_id_valid      (if_id_reg.valid),
    .id_ex_valid      (id_ex_reg.valid),
    .if_id_rs1        (if_id_reg.inst[19:15]),
    .if_id_rs2        (if_id_reg.inst[24:20]),
    .id_ex_rs1        (id_ex_reg.rs1),
    .id_ex_rs2        (id_ex_reg.rs2),
    .id_ex_rd         (id_ex_reg.rd),
    .id_ex_mem_read   (id_ex_reg.mem_read),
    .ex_mem_rd        (ex_mem_reg.rd),
    .ex_mem_reg_write (ex_mem_reg.reg_write),
    .mem_wb_rd        (mem_wb_reg.rd),
    .mem_wb_reg_write (mem_wb_reg.reg_write),
    .mispredict       (mispredict),
    .forward_a        (forward_a),
    .forward_b        (forward_b),
    .stall_if         (stall_if),
    .stall_id         (stall_id),
    .flush_if         (flush_if),
    .flush_id         (flush_id),
    .flush_ex         (flush_ex)
  );

endmodule
