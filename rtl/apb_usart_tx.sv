module apb_usart_tx
  import apb_usart_pkg::*;
#(
  parameter int FIFO_DEPTH = 16
)
(
  input  logic                     i_usart_clk,
  input  logic                     i_usart_rst_n,

  input  logic                     i_usart_en,
  input  logic                     i_usart_tx_en,
  input  apb_usart_mode_e          i_usart_mode,
  input  apb_usart_parity_e        i_usart_parity,
  input  apb_usart_stop_e          i_usart_stop,
  input  logic [3:0]               i_usart_data_bits,

  input  logic                     i_usart_baud_tick,

  input  logic [8:0]               i_usart_wr_data,
  input  logic                     i_usart_wr_en,
  input  logic                     i_usart_fifo_clear,
  output logic                     o_usart_tx_full,
  output logic                     o_usart_tx_empty,

  output logic                     o_usart_txd,
  output logic                     o_usart_sclk,

  output logic                     o_usart_busy,
  output logic                     o_usart_done
);

  logic [8:0] w_fifo_rd_data;
  logic       w_fifo_valid;
  logic       w_fifo_rd_en;

  apb_usart_fifo #(
    .DATA_WIDTH (9),
    .DEPTH      (FIFO_DEPTH)
  ) u_tx_fifo (
    .i_usart_clk     (i_usart_clk),
    .i_usart_rst_n   (i_usart_rst_n),
    .i_usart_clear   (!i_usart_en || i_usart_fifo_clear),
    .i_usart_wr_en   (i_usart_wr_en && !o_usart_tx_full),
    .i_usart_wr_data (i_usart_wr_data),
    .o_usart_full    (o_usart_tx_full),
    .i_usart_rd_en   (w_fifo_rd_en),
    .o_usart_rd_data (w_fifo_rd_data),
    .o_usart_empty   (o_usart_tx_empty),
    .o_usart_valid   (w_fifo_valid)
  );

  apb_usart_tx_state_e r_state;
  logic [8:0]  r_shift;
  logic [3:0]  r_bit_cnt;
  logic [3:0]  r_sub_cnt;
  logic        r_txd;
  logic        r_sclk;
  logic        r_done;
  logic        r_parity_bit;

  assign w_fifo_rd_en = (r_state == USART_TX_IDLE) && w_fifo_valid
                         && i_usart_en && i_usart_tx_en;
  assign o_usart_busy = (r_state != USART_TX_IDLE);
  assign o_usart_done = r_done;
  assign o_usart_txd  = r_txd;
  assign o_usart_sclk = r_sclk;

  function automatic logic calc_parity(input logic [8:0] data, input logic [3:0] bits);
    logic [8:0] mask;
    begin
      mask = (9'd1 << bits) - 9'd1;
      calc_parity = ^(data & mask);
    end
  endfunction

  always_ff @(posedge i_usart_clk or negedge i_usart_rst_n) begin
    if (!i_usart_rst_n) begin
      r_state      <= USART_TX_IDLE;
      r_shift      <= '0;
      r_bit_cnt    <= 4'd0;
      r_sub_cnt    <= 4'd0;
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
      end else if ((r_state == USART_TX_IDLE) && w_fifo_valid) begin
        r_shift      <= w_fifo_rd_data;
        r_bit_cnt    <= i_usart_data_bits - 4'd1;
        r_parity_bit <= calc_parity(w_fifo_rd_data, i_usart_data_bits);
        r_sub_cnt    <= 4'd0;
        r_txd        <= 1'b0;
        r_sclk       <= 1'b0;
        r_state      <= USART_TX_START;
      end else if (r_state == USART_TX_DONE) begin
        r_done  <= 1'b1;
        r_txd   <= 1'b1;
        r_sclk  <= 1'b0;
        r_state <= USART_TX_IDLE;
      end else if (i_usart_baud_tick) begin
        r_sclk <= 1'b0;
        unique case (r_state)
          USART_TX_IDLE: begin
            r_txd <= 1'b1;
          end

          USART_TX_START: begin
            r_txd <= 1'b0;
            if (r_sub_cnt == 4'd15) begin
              r_sub_cnt <= 4'd0;
              r_txd     <= r_shift[0];
              r_state   <= USART_TX_DATA;
            end else begin
              r_sub_cnt <= r_sub_cnt + 4'd1;
            end
          end

          USART_TX_DATA: begin
            if (i_usart_mode == USART_MODE_SYNC)
              r_sclk <= (r_sub_cnt < 4'd8);

            if (r_sub_cnt == 4'd15) begin
              r_sub_cnt <= 4'd0;
              if (r_bit_cnt == 4'd0) begin
                if (i_usart_parity != USART_PARITY_NONE) begin
                  unique case (i_usart_parity)
                    USART_PARITY_ODD:  r_txd <= ~r_parity_bit;
                    USART_PARITY_EVEN: r_txd <=  r_parity_bit;
                    default:           r_txd <= 1'b1;
                  endcase
                  r_state <= USART_TX_PARITY;
                end else begin
                  r_txd   <= 1'b1;
                  r_state <= USART_TX_STOP;
                end
              end else begin
                r_shift   <= {1'b1, r_shift[8:1]};
                r_txd     <= r_shift[1];
                r_bit_cnt <= r_bit_cnt - 4'd1;
              end
            end else begin
              r_sub_cnt <= r_sub_cnt + 4'd1;
            end
          end

          USART_TX_PARITY: begin
            if (r_sub_cnt == 4'd15) begin
              r_sub_cnt <= 4'd0;
              r_txd     <= 1'b1;
              r_state   <= USART_TX_STOP;
            end else begin
              r_sub_cnt <= r_sub_cnt + 4'd1;
            end
          end

          USART_TX_STOP: begin
            r_txd <= 1'b1;
            if (r_sub_cnt == 4'd15) begin
              r_sub_cnt <= 4'd0;
              if (i_usart_stop == USART_STOP_1) begin
                r_state <= USART_TX_DONE;
              end else begin
                r_state <= USART_TX_STOP2;
              end
            end else begin
              r_sub_cnt <= r_sub_cnt + 4'd1;
            end
          end

          USART_TX_STOP2: begin
            r_txd <= 1'b1;
            if (r_sub_cnt == ((i_usart_stop == USART_STOP_1P5) ? 4'd7 : 4'd15)) begin
              r_sub_cnt <= 4'd0;
              r_state   <= USART_TX_DONE;
            end else begin
              r_sub_cnt <= r_sub_cnt + 4'd1;
            end
          end

          default: r_state <= USART_TX_IDLE;
        endcase
      end
    end
  end

endmodule
