module apb_usart_rx
  import apb_usart_pkg::*;
#(
  parameter int FIFO_DEPTH = 16
)
(
  input  logic                     i_usart_clk,
  input  logic                     i_usart_rst_n,

  // Configuration
  input  logic                     i_usart_en,
  input  logic                     i_usart_rx_en,
  input  apb_usart_parity_e        i_usart_parity,
  input  apb_usart_stop_e          i_usart_stop,
  input  logic [3:0]               i_usart_data_bits, // 5..9

  // Baud ticks (16x oversample tick and mid-bit sample tick)
  input  logic                     i_usart_baud_tick,     // 16x tick
  input  logic                     i_usart_baud_tick_mid, // center sample

  // Serial input
  input  logic                     i_usart_rxd,

  // RX FIFO pop interface (from APB register read)
  input  logic                     i_usart_rd_en,
  output logic [8:0]               o_usart_rd_data,
  output logic                     o_usart_rx_full,
  output logic                     o_usart_rx_valid,

  // Error flags (sticky — cleared externally via IRQ_STAT W1C)
  output logic                     o_usart_parity_err,
  output logic                     o_usart_frame_err,
  output logic                     o_usart_overrun_err,

  // Status
  output logic                     o_usart_rx_done   // one-pulse on valid frame
);

  // ── RX FIFO ────────────────────────────────────────────────────────
  logic [8:0] w_fifo_wr_data;
  logic       w_fifo_wr_en;

  apb_usart_fifo #(
    .DATA_WIDTH (9),
    .DEPTH      (FIFO_DEPTH)
  ) u_rx_fifo (
    .i_usart_clk     (i_usart_clk),
    .i_usart_rst_n   (i_usart_rst_n),
    .i_usart_clear   (!i_usart_en),
    .i_usart_wr_en   (w_fifo_wr_en),
    .i_usart_wr_data (w_fifo_wr_data),
    .o_usart_full    (o_usart_rx_full),
    .i_usart_rd_en   (i_usart_rd_en),
    .o_usart_rd_data (o_usart_rd_data),
    .o_usart_empty   (),
    .o_usart_valid   (o_usart_rx_valid)
  );

  // ── RX FSM ─────────────────────────────────────────────────────────
  apb_usart_rx_state_e r_state;
  logic [8:0]  r_shift;
  logic [3:0]  r_bit_cnt;
  logic [3:0]  r_sub_cnt;   // 16x oversampling sub-tick counter
  logic        r_parity_acc;
  logic        r_rxd_sync1, r_rxd_sync2, r_rxd_filt; // metastability + glitch

  logic        r_parity_err;
  logic        r_frame_err;
  logic        r_overrun_err;
  logic        r_rx_done;

  assign o_usart_parity_err  = r_parity_err;
  assign o_usart_frame_err   = r_frame_err;
  assign o_usart_overrun_err = r_overrun_err;
  assign o_usart_rx_done     = r_rx_done;

  // ── Two-stage synchronizer + majority filter for RXD ─────────────
  always_ff @(posedge i_usart_clk or negedge i_usart_rst_n) begin
    if (!i_usart_rst_n) begin
      r_rxd_sync1 <= 1'b1;
      r_rxd_sync2 <= 1'b1;
      r_rxd_filt  <= 1'b1;
    end else begin
      r_rxd_sync1 <= i_usart_rxd;
      r_rxd_sync2 <= r_rxd_sync1;
      r_rxd_filt  <= r_rxd_sync2;
    end
  end

  // ── Parity check helper ────────────────────────────────────────────
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
      r_state       <= USART_RX_IDLE;
      r_shift       <= '0;
      r_bit_cnt     <= 4'd0;
      r_sub_cnt     <= 4'd0;
      r_parity_acc  <= 1'b0;
      r_parity_err  <= 1'b0;
      r_frame_err   <= 1'b0;
      r_overrun_err <= 1'b0;
      r_rx_done     <= 1'b0;
      w_fifo_wr_en  <= 1'b0;
      w_fifo_wr_data<= '0;
    end else begin
      r_rx_done    <= 1'b0;
      w_fifo_wr_en <= 1'b0;

      if (!i_usart_en || !i_usart_rx_en) begin
        r_state <= USART_RX_IDLE;
      end else begin
        unique case (r_state)
          // ── IDLE: wait for falling edge (start bit) ─────────────
          USART_RX_IDLE: begin
            if (!r_rxd_filt) begin
              r_sub_cnt <= 4'd0;
              r_state   <= USART_RX_START;
            end
          end

          // ── START: wait to sample at center (8 sub-ticks in) ────
          USART_RX_START: begin
            if (i_usart_baud_tick) begin
              r_sub_cnt <= r_sub_cnt + 4'd1;
              if (r_sub_cnt == 4'd7) begin
                // Sample at center of start bit
                if (!r_rxd_filt) begin
                  // Valid start bit confirmed
                  r_bit_cnt   <= i_usart_data_bits - 4'd1;
                  r_parity_acc<= 1'b0;
                  r_shift     <= '0;
                  r_sub_cnt   <= 4'd0;
                  r_state     <= USART_RX_DATA;
                end else begin
                  // Glitch — back to idle
                  r_state <= USART_RX_IDLE;
                end
              end
            end
          end

          // ── DATA: sample each bit at center (16 sub-ticks apart) ─
          USART_RX_DATA: begin
            if (i_usart_baud_tick_mid) begin
              // Sample
              r_shift      <= {r_rxd_filt, r_shift[8:1]};
              r_parity_acc <= r_parity_acc ^ r_rxd_filt;
              if (r_bit_cnt == 4'd0) begin
                if (i_usart_parity != USART_PARITY_NONE) begin
                  r_state <= USART_RX_PARITY;
                end else begin
                  r_state <= USART_RX_STOP;
                end
              end else begin
                r_bit_cnt <= r_bit_cnt - 4'd1;
              end
            end
          end

          // ── PARITY: sample parity bit ────────────────────────────
          USART_RX_PARITY: begin
            if (i_usart_baud_tick_mid) begin
              unique case (i_usart_parity)
                USART_PARITY_ODD:
                  if (r_parity_acc == r_rxd_filt) r_parity_err <= 1'b1;
                USART_PARITY_EVEN:
                  if (r_parity_acc != r_rxd_filt) r_parity_err <= 1'b1;
                default: ;
              endcase
              r_state <= USART_RX_STOP;
            end
          end

          // ── STOP: verify stop bit ────────────────────────────────
          USART_RX_STOP: begin
            if (i_usart_baud_tick_mid) begin
              if (!r_rxd_filt) begin
                // Missing stop bit → framing error
                r_frame_err <= 1'b1;
              end
              r_state <= USART_RX_DONE;
            end
          end

          // ── DONE: push to FIFO ────────────────────────────────────
          USART_RX_DONE: begin
            if (!o_usart_rx_full) begin
              w_fifo_wr_data <= r_shift;
              w_fifo_wr_en   <= 1'b1;
            end else begin
              r_overrun_err <= 1'b1;
            end
            r_rx_done <= 1'b1;
            r_state   <= USART_RX_IDLE;
          end

          default: r_state <= USART_RX_IDLE;
        endcase
      end
    end
  end

endmodule
