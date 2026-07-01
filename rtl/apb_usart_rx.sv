module apb_usart_rx
  import apb_usart_pkg::*;
#(
  parameter int FIFO_DEPTH = 16
)
(
  input  logic                     i_usart_clk,
  input  logic                     i_usart_rst_n,

  input  logic                     i_usart_en,
  input  logic                     i_usart_rx_en,
  input  apb_usart_parity_e        i_usart_parity,
  input  apb_usart_stop_e          i_usart_stop,
  input  logic [3:0]               i_usart_data_bits,

  input  logic                     i_usart_baud_tick,

  input  logic                     i_usart_rxd,

  input  logic                     i_usart_rd_en,
  input  logic                     i_usart_fifo_clear,
  output logic [8:0]               o_usart_rd_data,
  output logic                     o_usart_rx_full,
  output logic                     o_usart_rx_valid,

  output logic                     o_usart_parity_err,
  output logic                     o_usart_frame_err,
  output logic                     o_usart_overrun_err,

  output logic                     o_usart_rx_done
);

  logic [8:0] r_fifo_wr_data;
  logic       r_fifo_wr_en;

  apb_usart_fifo #(
    .DATA_WIDTH (9),
    .DEPTH      (FIFO_DEPTH)
  ) u_rx_fifo (
    .i_usart_clk     (i_usart_clk),
    .i_usart_rst_n   (i_usart_rst_n),
    .i_usart_clear   (!i_usart_en || i_usart_fifo_clear),
    .i_usart_wr_en   (r_fifo_wr_en),
    .i_usart_wr_data (r_fifo_wr_data),
    .o_usart_full    (o_usart_rx_full),
    .i_usart_rd_en   (i_usart_rd_en),
    .o_usart_rd_data (o_usart_rd_data),
    .o_usart_empty   (),
    .o_usart_valid   (o_usart_rx_valid)
  );

  apb_usart_rx_state_e r_state;
  logic [8:0]  r_shift;
  logic [3:0]  r_bit_cnt;
  logic [3:0]  r_sub_cnt;
  logic        r_parity_acc;

  logic        r_rxd_sync1;
  logic        r_rxd_sync2;
  logic        r_rxd_sync3;
  logic        r_rxd_filt;

  logic        r_parity_err;
  logic        r_frame_err;
  logic        r_overrun_err;
  logic        r_rx_done;

  assign o_usart_parity_err  = r_parity_err;
  assign o_usart_frame_err   = r_frame_err;
  assign o_usart_overrun_err = r_overrun_err;
  assign o_usart_rx_done     = r_rx_done;

  always_ff @(posedge i_usart_clk or negedge i_usart_rst_n) begin
    if (!i_usart_rst_n) begin
      r_rxd_sync1 <= 1'b1;
      r_rxd_sync2 <= 1'b1;
      r_rxd_sync3 <= 1'b1;
      r_rxd_filt  <= 1'b1;
    end else begin
      r_rxd_sync1 <= i_usart_rxd;
      r_rxd_sync2 <= r_rxd_sync1;
      r_rxd_sync3 <= r_rxd_sync2;
      r_rxd_filt  <= (r_rxd_sync1 & r_rxd_sync2) | (r_rxd_sync2 & r_rxd_sync3) | (r_rxd_sync1 & r_rxd_sync3);
    end
  end

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
      r_fifo_wr_en  <= 1'b0;
      r_fifo_wr_data<= '0;
    end else begin
      r_rx_done     <= 1'b0;
      r_parity_err  <= 1'b0;
      r_frame_err   <= 1'b0;
      r_overrun_err <= 1'b0;
      r_fifo_wr_en  <= 1'b0;

      if (!i_usart_en || !i_usart_rx_en) begin
        r_state <= USART_RX_IDLE;
      end else if ((r_state == USART_RX_IDLE) && !r_rxd_filt) begin
        r_sub_cnt    <= 4'd0;
        r_parity_acc <= 1'b0;
        r_shift      <= '0;
        r_state      <= USART_RX_START;
      end else if (r_state == USART_RX_DONE) begin
        if (!o_usart_rx_full) begin
          r_fifo_wr_en   <= 1'b1;
          r_fifo_wr_data <= r_shift >> (4'd9 - i_usart_data_bits);
        end else begin
          r_overrun_err <= 1'b1;
        end
        r_rx_done <= 1'b1;
        r_state   <= USART_RX_IDLE;
      end else if (i_usart_baud_tick) begin
        unique case (r_state)
          USART_RX_IDLE: ;

          USART_RX_START: begin
            if (r_sub_cnt == 4'd7) begin
              if (!r_rxd_filt) begin
                r_sub_cnt <= 4'd0;
                r_bit_cnt <= 4'd0;
                r_state   <= USART_RX_DATA;
              end else begin
                r_state <= USART_RX_IDLE;
              end
            end else begin
              r_sub_cnt <= r_sub_cnt + 4'd1;
            end
          end

          USART_RX_DATA: begin
            if (r_sub_cnt == 4'd15) begin
              r_sub_cnt    <= 4'd0;
              r_shift      <= {r_rxd_filt, r_shift[8:1]};
              r_parity_acc <= r_parity_acc ^ r_rxd_filt;
              if (r_bit_cnt == i_usart_data_bits - 4'd1) begin
                if (i_usart_parity != USART_PARITY_NONE) begin
                  r_state <= USART_RX_PARITY;
                end else begin
                  r_state <= USART_RX_STOP;
                end
              end else begin
                r_bit_cnt <= r_bit_cnt + 4'd1;
              end
            end else begin
              r_sub_cnt <= r_sub_cnt + 4'd1;
            end
          end

          USART_RX_PARITY: begin
            if (r_sub_cnt == 4'd15) begin
              r_sub_cnt <= 4'd0;
              unique case (i_usart_parity)
                USART_PARITY_ODD:
                  if (r_parity_acc == r_rxd_filt) r_parity_err <= 1'b1;
                USART_PARITY_EVEN:
                  if (r_parity_acc != r_rxd_filt) r_parity_err <= 1'b1;
                default: ;
              endcase
              r_state <= USART_RX_STOP;
            end else begin
              r_sub_cnt <= r_sub_cnt + 4'd1;
            end
          end

          USART_RX_STOP: begin
            if (r_sub_cnt == 4'd15) begin
              r_sub_cnt <= 4'd0;
              if (!r_rxd_filt) r_frame_err <= 1'b1;
              r_state <= USART_RX_DONE;
            end else begin
              r_sub_cnt <= r_sub_cnt + 4'd1;
            end
          end

          default: r_state <= USART_RX_IDLE;
        endcase
      end
    end
  end

endmodule
