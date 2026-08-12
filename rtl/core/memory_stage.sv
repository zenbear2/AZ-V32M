// ============================================================================
// File: memory_stage.sv
// Description: Memory Access Stage & Load/Store Formatting
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module memory_stage (
  input  ex_mem_reg_t ex_mem_in,

  // Data Memory Interface
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_byte_enable,
  output logic        dmem_req,
  output logic        dmem_we,
  input  logic [31:0] dmem_rdata,

  // Output to MEM/WB Register
  output mem_wb_reg_t mem_wb_out
);

  logic [1:0] byte_offset;
  logic [31:0] formatted_rdata;

  assign dmem_addr   = {ex_mem_in.alu_result[31:2], 2'b00};
  assign byte_offset = ex_mem_in.alu_result[1:0];
  assign dmem_req    = ex_mem_in.valid && (ex_mem_in.mem_read || ex_mem_in.mem_write);
  assign dmem_we     = ex_mem_in.valid && ex_mem_in.mem_write;

  // Write Data & Byte Enable Generation
  always_comb begin
    dmem_wdata       = 32'd0;
    dmem_byte_enable = 4'b0000;

    if (ex_mem_in.valid && ex_mem_in.mem_write) begin
      case (ex_mem_in.mem_width)
        MEM_BYTE: begin
          dmem_wdata       = {4{ex_mem_in.rs2_data[7:0]}};
          dmem_byte_enable = 4'b0001 << byte_offset;
        end
        MEM_HALF: begin
          dmem_wdata       = {2{ex_mem_in.rs2_data[15:0]}};
          dmem_byte_enable = (byte_offset[1]) ? 4'b1100 : 4'b0011;
        end
        MEM_WORD: begin
          dmem_wdata       = ex_mem_in.rs2_data;
          dmem_byte_enable = 4'b1111;
        end
        default: ;
      endcase
    end
  end

  // Read Data Formatting (Sign/Zero Extension)
  always_comb begin
    case (ex_mem_in.mem_width)
      MEM_BYTE: begin
        case (byte_offset)
          2'b00: formatted_rdata = {{24{dmem_rdata[7]}},   dmem_rdata[7:0]};
          2'b01: formatted_rdata = {{24{dmem_rdata[15]}},  dmem_rdata[15:8]};
          2'b10: formatted_rdata = {{24{dmem_rdata[23]}},  dmem_rdata[23:16]};
          2'b11: formatted_rdata = {{24{dmem_rdata[31]}},  dmem_rdata[31:24]};
        endcase
      end
      MEM_HALF: begin
        if (byte_offset[1]) begin
          formatted_rdata = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
        end else begin
          formatted_rdata = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
        end
      end
      MEM_WORD: begin
        formatted_rdata = dmem_rdata;
      end
      MEM_BYTEU: begin
        case (byte_offset)
          2'b00: formatted_rdata = {24'd0, dmem_rdata[7:0]};
          2'b01: formatted_rdata = {24'd0, dmem_rdata[15:8]};
          2'b10: formatted_rdata = {24'd0, dmem_rdata[23:16]};
          2'b11: formatted_rdata = {24'd0, dmem_rdata[31:24]};
        endcase
      end
      MEM_HALFU: begin
        if (byte_offset[1]) begin
          formatted_rdata = {16'd0, dmem_rdata[31:16]};
        end else begin
          formatted_rdata = {16'd0, dmem_rdata[15:0]};
        end
      end
      default: formatted_rdata = dmem_rdata;
    endcase
  end

  // Output to MEM/WB Register
  always_comb begin
    mem_wb_out.valid      = ex_mem_in.valid;
    mem_wb_out.pc_plus4   = ex_mem_in.pc_plus4;
    mem_wb_out.alu_result = ex_mem_in.alu_result;
    mem_wb_out.mem_rdata  = formatted_rdata;
    mem_wb_out.rd         = ex_mem_in.rd;
    mem_wb_out.reg_write  = ex_mem_in.valid && ex_mem_in.reg_write;
    mem_wb_out.wb_src     = ex_mem_in.wb_src;
  end

endmodule
