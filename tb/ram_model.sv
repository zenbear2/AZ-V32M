// ============================================================================
// File: ram_model.sv
// Description: Dual-Port Unified Memory Model with MMIO support for Verilator
// Project: AZ_V RISC-V CPU
// ============================================================================

module ram_model #(
  parameter int MEM_SIZE_BYTES = 4096, // 4 KB memory
  parameter string HEX_FILE     = ""
)(
  input  logic        clk,
  input  logic        rst_n,

  // Instruction Port
  input  logic [31:0] imem_addr,
  output logic [31:0] imem_rdata,

  // Data Port
  input  logic [31:0] dmem_addr,
  input  logic [31:0] dmem_wdata,
  input  logic [3:0]  dmem_byte_enable,
  input  logic        dmem_req,
  input  logic        dmem_we,
  output logic [31:0] dmem_rdata,

  // Simulation Status Port
  output logic        sim_exit,
  output logic [31:0] exit_code
);

  logic [7:0] mem [0:MEM_SIZE_BYTES-1];

  // Initialize Memory
  initial begin
    integer i;
    string hex_file;
    sim_exit = 1'b0;
    exit_code = 32'h0;
    for (i = 0; i < MEM_SIZE_BYTES; i = i + 1) begin
      mem[i] = 8'h00;
    end
    if ($value$plusargs("HEX=%s", hex_file)) begin
      $readmemh(hex_file, mem);
    end else if (HEX_FILE != "") begin
      $readmemh(HEX_FILE, mem);
    end
  end

  // Instruction Read (Combinational / Single-cycle)
  always_comb begin
    if (imem_addr < MEM_SIZE_BYTES - 3) begin
      imem_rdata = {mem[imem_addr + 3],
                    mem[imem_addr + 2],
                    mem[imem_addr + 1],
                    mem[imem_addr + 0]};
    end else begin
      imem_rdata = 32'h0000_0013; // NOP (addi x0, x0, 0)
    end
  end

  // Data Read (Combinational)
  always_comb begin
    if (dmem_req && !dmem_we && (dmem_addr < MEM_SIZE_BYTES - 3)) begin
      dmem_rdata = {mem[dmem_addr + 3],
                    mem[dmem_addr + 2],
                    mem[dmem_addr + 1],
                    mem[dmem_addr + 0]};
    end else begin
      dmem_rdata = 32'h0000_0000;
    end
  end

  // Data Write (Synchronous) & MMIO Trapping
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sim_exit  <= 1'b0;
      exit_code <= 32'h0;
    end else if (dmem_req && dmem_we) begin
      if (dmem_addr == 32'h0000_fff0) begin
        $write("%c", dmem_wdata[7:0]);
        $fflush();
      end else if (dmem_addr == 32'h0000_fff4) begin
        sim_exit  <= 1'b1;
        exit_code <= dmem_wdata;
      end else if (dmem_addr < MEM_SIZE_BYTES - 3) begin
        if (dmem_byte_enable[0]) mem[dmem_addr + 0] <= dmem_wdata[7:0];
        if (dmem_byte_enable[1]) mem[dmem_addr + 1] <= dmem_wdata[15:8];
        if (dmem_byte_enable[2]) mem[dmem_addr + 2] <= dmem_wdata[23:16];
        if (dmem_byte_enable[3]) mem[dmem_addr + 3] <= dmem_wdata[31:24];
      end
    end
  end

endmodule
