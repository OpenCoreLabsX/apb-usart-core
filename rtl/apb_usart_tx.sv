module apb_usart_tx
  import apb_usart_pkg::*;
#(
  parameter int FIFO_DEPTH = 16
)
(
  input  logic                     i_usart_clk,
  input  logic                     i_usart_rst_n,

  // Configuration
  input  logic                     i_usart_en,
  input  logic                     i_usart_tx_en,
  input  apb_usart_mode_e          i_usart_mode,
  input  apb_usart_parity_e        i_usart_parity,
  input  apb_usart_stop_e          i_usart_stop,
  input  logic [3:0]               i_usart_data_bits, // 5..9

  // Baud tick (1x tick = one bit period)
  input  logic                     i_usart_baud_tick,

  // TX FIFO push interface (from APB register write)
  input  logic [8:0]               i_usart_wr_data,   // up to 9-bit data
  input  logic                     i_usart_wr_en,
  output logic                     o_usart_tx_full,
  output logic                     o_usart_tx_empty,

  // Serial output
  output logic                     o_usart_txd,
  output logic                     o_usart_sclk,     // USART sync mode clock

  // Status
  output logic                     o_usart_busy,
  output logic                     o_usart_done      // one-pulse when frame complete
);

  // ── TX FIFO ────────────────────────────────────────────────────────
  logic [8:0] w_fifo_rd_data;
  logic       w_fifo_valid;
  logic       w_fifo_rd_en;

  apb_usart_fifo #(
    .DATA_WIDTH (9),
    .DEPTH      (FIFO_DEPTH)
  ) u_tx_fifo (
    .i_usart_clk     (i_usart_clk),
    .i_usart_rst_n   (i_usart_rst_n),
    .i_usart_clear   (!i_usart_en),
    .i_usart_wr_en   (i_usart_wr_en && !o_usart_tx_full),
    .i_usart_wr_data (i_usart_wr_data),
    .o_usart_full    (o_usart_tx_full),
    .i_usart_rd_en   (w_fifo_rd_en),
    .o_usart_rd_data (w_fifo_rd_data),
    .o_usart_empty   (o_usart_tx_empty),
    .o_usart_valid   (w_fifo_valid)
  );

  // ── TX shift register ──────────────────────────────────────────────
  apb_usart_tx_state_e r_state;
  logic [8:0]  r_shift;
  logic [3:0]  r_bit_cnt;
  logic [1:0]  r_stop_cnt;
  logic        r_txd;
  logic        r_sclk;
  logic        r_done;
  logic        r_parity_bit;

  assign w_fifo_rd_en = (r_state == USART_TX_IDLE) && w_fifo_valid && i_usart_baud_tick && i_usart_tx_en;
  assign o_usart_busy = (r_state != USART_TX_IDLE);
  assign o_usart_done = r_done;
  assign o_usart_txd  = r_txd;
  assign o_usart_sclk = r_sclk;

  // Compute parity over loaded data
  function automatic logic calc_parity(input logic [8:0] data, input logic [3:0] bits);
    logic p;
    int   i;
    begin
      p = 1'b0;
      for (i = 0; i < 9; i++) begin
        if (i < int'(bits)) p = p ^ data[i];
      end
      calc_parity = p;
    end
  endfunction

  always_ff @(posedge i_usart_clk or negedge i_usart_rst_n) begin
    if (!i_usart_rst_n) begin
      r_state      <= USART_TX_IDLE;
      r_shift      <= '1;
      r_bit_cnt    <= 4'd0;
      r_stop_cnt   <= 2'd0;
      r_txd        <= 1'b1;
      r_sclk       <= 1'b0;
      r_done       <= 1'b0;
      r_parity_bit <= 1'b0;
    end else begin
      r_done <= 1'b0;

      if (!i_usart_en || !i_usart_tx_en) begin
        r_state <= USART_TX_IDLE;
        r_txd   <= 1'b1;
        r_sclk  <= 1'b0;
      end else if (i_usart_baud_tick) begin
        unique case (r_state)
          // ── IDLE: wait for data in FIFO ──────────────────────────
          USART_TX_IDLE: begin
            r_txd  <= 1'b1;
            r_sclk <= 1'b0;
            if (w_fifo_valid && i_usart_tx_en) begin
              // Data loaded from FIFO via w_fifo_rd_en pulse above
              r_shift      <= w_fifo_rd_data;
              r_bit_cnt    <= i_usart_data_bits - 4'd1;
              r_parity_bit <= calc_parity(w_fifo_rd_data, i_usart_data_bits);
              r_state      <= USART_TX_START;
            end
          end

          // ── START bit ─────────────────────────────────────────────
          USART_TX_START: begin
            r_txd   <= 1'b0;
            r_sclk  <= 1'b0;
            r_state <= USART_TX_DATA;
          end

          // ── DATA bits (LSB first) ─────────────────────────────────
          USART_TX_DATA: begin
            r_txd  <= r_shift[0];
            r_sclk <= ~r_sclk; // toggle SCLK in sync mode
            r_shift <= {1'b1, r_shift[8:1]};
            if (r_bit_cnt == 4'd0) begin
              if (i_usart_parity != USART_PARITY_NONE) begin
                r_state <= USART_TX_PARITY;
              end else begin
                r_stop_cnt <= (i_usart_stop == USART_STOP_2) ? 2'd1 : 2'd0;
                r_state    <= USART_TX_STOP;
              end
            end else begin
              r_bit_cnt <= r_bit_cnt - 4'd1;
            end
          end

          // ── PARITY bit ────────────────────────────────────────────
          USART_TX_PARITY: begin
            unique case (i_usart_parity)
              USART_PARITY_ODD:  r_txd <= ~r_parity_bit;
              USART_PARITY_EVEN: r_txd <=  r_parity_bit;
              default:           r_txd <= 1'b1;
            endcase
            r_sclk     <= 1'b0;
            r_stop_cnt <= (i_usart_stop == USART_STOP_2) ? 2'd1 : 2'd0;
            r_state    <= USART_TX_STOP;
          end

          // ── STOP bit(s) ───────────────────────────────────────────
          USART_TX_STOP: begin
            r_txd  <= 1'b1;
            r_sclk <= 1'b0;
            if (r_stop_cnt != 2'd0) begin
              r_stop_cnt <= r_stop_cnt - 2'd1;
              r_state    <= USART_TX_STOP2;
            end else begin
              r_state <= USART_TX_DONE;
            end
          end

          USART_TX_STOP2: begin
            r_txd   <= 1'b1;
            r_state <= USART_TX_DONE;
          end

          // ── DONE ──────────────────────────────────────────────────
          USART_TX_DONE: begin
            r_done  <= 1'b1;
            r_state <= USART_TX_IDLE;
          end

          default: r_state <= USART_TX_IDLE;
        endcase
      end
    end
  end

endmodule
