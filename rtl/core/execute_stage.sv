// ============================================================================
// File: execute_stage.sv
// Description: Execute Stage with Forwarding, ALU, and Branch Resolution
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module execute_stage (
  input  id_ex_reg_t  id_ex_in,

  // Forwarding Inputs from EX/MEM and MEM/WB
  input  logic [1:0]  forward_a,
  input  logic [1:0]  forward_b,
  input  logic [31:0] ex_mem_alu_result,
  input  logic [31:0] mem_wb_result,

  // Branch Misprediction Redirect Interface (to Fetch Unit)
  output logic        mispredict,
  output logic [31:0] redirect_target,

  // BPU Update Interface (to Fetch Unit)
  output logic        bpu_update_en,
  output logic [31:0] bpu_update_pc,
  output logic [31:0] bpu_update_target,
  output logic        bpu_actual_taken,

  // Output to EX/MEM Pipeline Register
  output ex_mem_reg_t ex_mem_out
);

  logic [31:0] operand_a_fw;
  logic [31:0] operand_b_fw;
  logic [31:0] alu_operand_a;
  logic [31:0] alu_operand_b;
  logic [31:0] alu_result;
  logic        alu_zero;

  // Forwarding Mux for Operand A (rs1)
  always_comb begin
    case (forward_a)
      2'b01:   operand_a_fw = ex_mem_alu_result;
      2'b10:   operand_a_fw = mem_wb_result;
      default: operand_a_fw = id_ex_in.rs1_data;
    endcase
  end

  // Forwarding Mux for Operand B (rs2)
  always_comb begin
    case (forward_b)
      2'b01:   operand_b_fw = ex_mem_alu_result;
      2'b10:   operand_b_fw = mem_wb_result;
      default: operand_b_fw = id_ex_in.rs2_data;
    endcase
  end

  // Flattened Direct ALU Input Muxes (eliminates cascading multiplexer delay)
  always_comb begin
    if (id_ex_in.alu_src_a_pc) begin
      alu_operand_a = id_ex_in.pc;
    end else begin
      case (forward_a)
        2'b01:   alu_operand_a = ex_mem_alu_result;
        2'b10:   alu_operand_a = mem_wb_result;
        default: alu_operand_a = id_ex_in.rs1_data;
      endcase
    end
  end

  always_comb begin
    if (id_ex_in.alu_src_b == ALU_SRC_IMM) begin
      alu_operand_b = id_ex_in.imm;
    end else begin
      case (forward_b)
        2'b01:   alu_operand_b = ex_mem_alu_result;
        2'b10:   alu_operand_b = mem_wb_result;
        default: alu_operand_b = id_ex_in.rs2_data;
      endcase
    end
  end

  // ALU Instance
  alu u_alu (
    .a      (alu_operand_a),
    .b      (alu_operand_b),
    .alu_op (id_ex_in.alu_op),
    .result (alu_result),
    .zero   (alu_zero)
  );

  // Branch & Jump Condition Evaluation (Optimized: shared comparators & parallel adders)
  logic actual_taken;
  logic [31:0] branch_jal_target;
  logic [31:0] jalr_target;
  logic [31:0] computed_target;
  logic [31:0] actual_next_pc;

  // Target Address Computation (Parallelized: Branch/JAL does not wait for forwarding)
  assign branch_jal_target = id_ex_in.pc + id_ex_in.imm;
  assign jalr_target       = (operand_a_fw + id_ex_in.imm) & ~32'd1;
  assign computed_target   = (id_ex_in.is_jalr) ? jalr_target : branch_jal_target;

  logic is_eq, is_lt_signed, is_lt_unsigned;
  assign is_eq          = (operand_a_fw == operand_b_fw);
  assign is_lt_unsigned = (operand_a_fw < operand_b_fw);
  assign is_lt_signed   = ($signed(operand_a_fw) < $signed(operand_b_fw));

  always_comb begin
    actual_taken = 1'b0;
    case (id_ex_in.branch_type)
      BRANCH_BEQ:  actual_taken = is_eq;
      BRANCH_BNE:  actual_taken = !is_eq;
      BRANCH_BLT:  actual_taken = is_lt_signed;
      BRANCH_BGE:  actual_taken = !is_lt_signed;
      BRANCH_BLTU: actual_taken = is_lt_unsigned;
      BRANCH_BGEU: actual_taken = !is_lt_unsigned;
      default:     actual_taken = 1'b0;
    endcase

    if (id_ex_in.is_jal || id_ex_in.is_jalr) begin
      actual_taken = 1'b1;
    end
  end

  assign actual_next_pc = (actual_taken) ? computed_target : id_ex_in.pc_plus4;

  // Branch Misprediction Check
  always_comb begin
    if (id_ex_in.valid && (id_ex_in.branch_type != BRANCH_NONE || id_ex_in.is_jal || id_ex_in.is_jalr)) begin
      if (id_ex_in.pred_info.pred_taken != actual_taken) begin
        mispredict      = 1'b1;
        redirect_target = actual_next_pc;
      end else if (actual_taken && (id_ex_in.pred_info.pred_target != computed_target)) begin
        mispredict      = 1'b1;
        redirect_target = computed_target;
      end else begin
        mispredict      = 1'b0;
        redirect_target = 32'd0;
      end
    end else begin
      mispredict      = 1'b0;
      redirect_target = 32'd0;
    end
  end

  // Predictor Update Interface
  assign bpu_update_en     = id_ex_in.valid && (id_ex_in.branch_type != BRANCH_NONE || id_ex_in.is_jal || id_ex_in.is_jalr);
  assign bpu_update_pc     = id_ex_in.pc;
  assign bpu_update_target = computed_target;
  assign bpu_actual_taken  = actual_taken;

  // Output to EX/MEM Register
  always_comb begin
    ex_mem_out.valid      = id_ex_in.valid;
    ex_mem_out.pc         = id_ex_in.pc;
    ex_mem_out.pc_plus4   = id_ex_in.pc_plus4;
    ex_mem_out.alu_result = alu_result;
    ex_mem_out.rs2_data   = operand_b_fw;
    ex_mem_out.rd         = id_ex_in.rd;

    ex_mem_out.mem_read   = id_ex_in.valid && id_ex_in.mem_read;
    ex_mem_out.mem_write  = id_ex_in.valid && id_ex_in.mem_write;
    ex_mem_out.mem_width  = id_ex_in.mem_width;
    ex_mem_out.reg_write  = id_ex_in.valid && id_ex_in.reg_write;
    ex_mem_out.wb_src     = id_ex_in.wb_src;

    ex_mem_out.bpu_update_en     = bpu_update_en;
    ex_mem_out.bpu_update_pc     = bpu_update_pc;
    ex_mem_out.bpu_update_target = bpu_update_target;
    ex_mem_out.bpu_actual_taken  = bpu_actual_taken;
  end

endmodule
