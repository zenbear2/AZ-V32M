// ============================================================================
// File: icache.sv
// Description: 2-Way Set-Associative Instruction Cache (LUTRAM-based)
// Project: AZ_V RISC-V CPU
// ============================================================================

import riscv_pkg::*;

module icache #(
  // TODO: 定義 NUM_SETS 等參數
  parameter int NUM_SETS = 32,
  parameter int NUM_WAYS = 2
)(
  // TODO: 定義 I/O Ports
  input  logic         clk,
  input  logic         rst_n,

  input  logic         cpu_req,
  input  logic [31:0]  cpu_addr,
  output logic [31:0]  cpu_rdata,
  output logic         icache_busy,

  output logic         mem_req,
  output logic [31:0]  mem_addr,
  input  logic [31:0]  mem_rdata,
  input  logic         mem_ready

);
  localparam int OFFSET_BITS = 4;
  localparam int INDEX_BITS  = $clog2(NUM_SETS);
  localparam int TAG_BITS    = 32 - INDEX_BITS - OFFSET_BITS;

  logic [TAG_BITS-1:0]    req_tag;
  logic [INDEX_BITS-1:0]  req_index;
  logic [1:0]             req_word;

  assign req_tag   = cpu_addr[31 : OFFSET_BITS + INDEX_BITS];               // [31:9] (23 bits)
  assign req_index = cpu_addr[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS];  // [8:4]  (5 bits)
  assign req_word  = cpu_addr[3:2];                                         // [3:2]  (2 bits)

  // 每個 Set、每個 Way 的 Valid 與 LRU 暫存器 (Flip-Flops)
  logic [NUM_WAYS-1:0] valid_array [0:NUM_SETS-1];
  logic                lru_bit     [0:NUM_SETS-1];

  // 與各個 Way 溝通的連線 (供 Stage 2 Refill 寫入與 Hit 讀取使用)
  logic [NUM_WAYS-1:0] way_hit;                        // 各 Way 是否 Hit
  logic [31:0]         way_word_rdata [0:NUM_WAYS-1];  // 各 Way 讀出的目標 32-bit Word
  logic [NUM_WAYS-1:0] way_refill_we;                  // Refill 時寫入哪一個 Way
  logic [1:0]          refill_word_cnt;                // Refill 正在寫入第幾個 Word (0~3)

  genvar w;
  generate
    for (w = 0; w < NUM_WAYS; w++) begin : gen_ways
      (* ram_style = "distributed" *) logic [TAG_BITS-1:0] tag_mem  [0:NUM_SETS-1];
      (* ram_style = "distributed" *) logic [3:0][31:0]    data_mem [0:NUM_SETS-1];

      // 1. 非同步讀取與 Hit 判定 (LUTRAM 0-cycle read)
      assign way_hit[w]        = valid_array[req_index][w] && (tag_mem[req_index] == req_tag);
      assign way_word_rdata[w] = data_mem[req_index][req_word];

      // 2. 同步寫入 (在 Refill 狀態收到外部記憶體資料時寫入 LUTRAM)
      always_ff @(posedge clk) begin
        if (way_refill_we[w]) begin
          data_mem[req_index][refill_word_cnt] <= mem_rdata;
          if (refill_word_cnt == 2'd3) begin
            tag_mem[req_index] <= req_tag;
          end
        end
      end
    end
  endgenerate

  // TODO: Stage 2 - Hit/Miss 判定、LRU 更新與 Refill FSM
  logic cache_hit;
  logic victim_way;

  assign cache_hit  = |way_hit;
  assign victim_way = lru_bit[req_index];

  // 1. CPU 讀取資料多工器 (Hit 時選擇對應 Way 的資料輸出)
  always_comb begin
    // TODO: 根據 way_hit 選擇輸出 way_word_rdata[1] 或 way_word_rdata[0]
    cpu_rdata = '0;
  end

  // 2. 狀態機定義
  typedef enum logic {
    STATE_IDLE,
    STATE_REFILL
  } state_e;

  state_e state_reg, state_next;

  // 3. 次態邏輯與對外控制訊號 (Combinational FSM)
  always_comb begin
    state_next    = state_reg;
    icache_busy   = 1'b0;
    mem_req       = 1'b0;
    mem_addr      = '0;
    way_refill_we = '0;

    case (state_reg)
      STATE_IDLE: begin
        // TODO: 若 cpu_req 且 !cache_hit (發生 Miss)：
        //   1. 拉高 icache_busy
        //   2. state_next 轉移至 STATE_REFILL
        if( cpu_req && !cache_hit )begin
            icache = 1;
            state_next = STATE_REFILL;
        end

      end

      STATE_REFILL: begin
        // TODO: Refill 狀態控制：
        //   1. 保持 icache_busy 為 1
        //   2. 拉高 mem_req，並設定 mem_addr = {cpu_addr[31:4], refill_word_cnt, 2'b00}
        //   3. 當 mem_ready 為 1 時：
        //      - 拉高對應的 way_refill_we[victim_way] = 1'b1
        //      - 若 refill_word_cnt == 2'd3，state_next 回到 STATE_IDLE
        icache = 1;
        mem_req = 1;
        mem_addr = {cpu_addr[31:4], refill_word_cnt, 2'b00};

        if(mem_ready)begin
            way_refill_we[victim_way] = 1'b1;
            if(refill_word_cnt == 2'd3)begin
                state_next = STATE_IDLE;
            end
        end

      end

      default: state_next = STATE_IDLE;
    endcase
  end

  // 4. 狀態暫存器、Word 計數器、Valid 與 LRU 更新 (Sequential Logic)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg       <= STATE_IDLE;
      refill_word_cnt <= 2'd0;
      for (int i = 0; i < NUM_SETS; i++) begin
        valid_array[i] <= '0;
        lru_bit[i]     <= 1'b0;
      end
    end else begin
      state_reg <= state_next;

      case (state_reg)
        STATE_IDLE: begin
          // TODO:
          // 1. 若 cpu_req && cache_hit：更新 lru_bit[req_index] (若 way_hit[0] 則設為 1，否則設為 0)
          // 2. 若 cpu_req && !cache_hit：將 refill_word_cnt 清為 2'd0
          if( cpu_req )begin

            if(cache_hit)begin

              lru_bit[req_index] <= way_hit[0] ? 1 : 0;

            end else begin

              refill_word_cnt <= '0;

            end

        end

        STATE_REFILL: begin
          // TODO:
          // 當 mem_ready 為 1 時：
          // 1. 若 refill_word_cnt == 2'd3：
          //    - 將 valid_array[req_index][victim_way] 設為 1'b1
          //    - 更新 lru_bit[req_index] <= ~victim_way
          //    - refill_word_cnt 清為 2'd0
          // 2. 否則：
          //    - refill_word_cnt 加 1

          if( mem_ready )begin

              if( refill_word_cnt == 2'd3 )begin
                
                valid_array[req_index][victim_way] <= 1;
                lru_bit[req_index] <= ~victim_way;
                refill_word_cnt <= '0


              end else begin

                  refill_word_cnt <= refill_word_cnt + 1;

              end

        end
      endcase
    end
  end

endmodule

