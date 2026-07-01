module apb_usart_baud_gen
(
  input  logic        i_usart_clk,
  input  logic        i_usart_rst_n,
  input  logic        i_usart_en,
  input  logic [15:0] i_usart_bauddiv,  // clock divider = f_clk / (baud * 16) - 1

  output logic        o_usart_tick,     // 16x baud tick
  output logic        o_usart_tick_mid  // tick at bit center (8th sub-tick)
);

  logic [15:0] r_cnt;
  logic [3:0]  r_sub_cnt;   // 0..15 sub-tick counter within one bit period

  assign o_usart_tick     = (r_cnt == 16'd0) && i_usart_en;
  assign o_usart_tick_mid = o_usart_tick && (r_sub_cnt == 4'd7);

  always_ff @(posedge i_usart_clk or negedge i_usart_rst_n) begin
    if (!i_usart_rst_n) begin
      r_cnt     <= 16'd0;
      r_sub_cnt <= 4'd0;
    end else if (!i_usart_en) begin
      r_cnt     <= i_usart_bauddiv;
      r_sub_cnt <= 4'd0;
    end else begin
      if (r_cnt == 16'd0) begin
        r_cnt     <= i_usart_bauddiv;
        r_sub_cnt <= r_sub_cnt + 4'd1;
      end else begin
        r_cnt <= r_cnt - 16'd1;
      end
    end
  end

endmodule
