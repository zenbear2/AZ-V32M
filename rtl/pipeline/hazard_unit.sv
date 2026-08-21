// ============================================================================
// File: hazard_unit.sv
// Description: Hazard Detection, Forwarding Control, Stall & Flush Logic
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module hazard_unit (
  // Valid Flags
  input  logic        if_id_valid,
  input  logic        id_ex_valid,

  // Source Register Addresses
  input  logic [4:0]  if_id_rs1,
  input  logic [4:0]  if_id_rs2,
  input  logic [4:0]  id_ex_rs1,
  input  logic [4:0]  id_ex_rs2,

  // Destination Register Addresses & Write Enables
  input  logic [4:0]  id_ex_rd,
  input  logic        id_ex_mem_read,

  input  logic [4:0]  ex_mem_rd,
  input  logic        ex_mem_reg_write,

  input  logic [4:0]  mem_wb_rd,
  input  logic        mem_wb_reg_write,

  // Branch Control
  input  logic        mispredict,

  // Debug Control
  input  logic        debug_halt,

  // Instruction Queue Status
  input  logic        iq_full,

  // Forwarding Mux Select Outputs
  output logic [1:0]  forward_a,
  output logic [1:0]  forward_b,

  // Pipeline Stall & Flush Control Outputs
  output logic        stall_if,
  output logic        stall_id,
  output logic        flush_if,
  output logic        flush_id,
  output logic        flush_ex
);

  // Data Forwarding Logic (EX Stage)
  always_comb begin
    // Forward A (rs1)
    if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
      forward_a = 2'b01; // Forward from EX/MEM
    end else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
      forward_a = 2'b10; // Forward from MEM/WB
    end else begin
      forward_a = 2'b00; // No forwarding
    end

    // Forward B (rs2)
    if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) begin
      forward_b = 2'b01; // Forward from EX/MEM
    end else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) begin
      forward_b = 2'b10; // Forward from MEM/WB
    end else begin
      forward_b = 2'b00; // No forwarding
    end
  end

  // Load-Use Hazard Detection
  logic load_use_hazard;
  assign load_use_hazard = if_id_valid && id_ex_valid && id_ex_mem_read && (id_ex_rd != 5'd0) &&
                           ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));

  // Pipeline Controls
  always_comb begin
    stall_if = load_use_hazard || debug_halt || iq_full;
    stall_id = load_use_hazard || debug_halt;

    flush_if = mispredict;
    flush_id = mispredict;
    flush_ex = load_use_hazard || mispredict;
  end

endmodule
