module apb_usart_baud_gen
(
  input  logic        i_usart_clk,
  input  logic        i_usart_rst_n,
  input  logic        i_usart_en,
  input  logic [15:0] i_usart_bauddiv,

  output logic        o_usart_tick
);

  logic [15:0] r_cnt;

  assign o_usart_tick = (r_cnt == 16'd0) && i_usart_en;

  always_ff @(posedge i_usart_clk or negedge i_usart_rst_n) begin
    if (!i_usart_rst_n) begin
      r_cnt <= 16'd0;
    end else if (!i_usart_en) begin
      r_cnt <= i_usart_bauddiv;
    end else if (r_cnt == 16'd0) begin
      r_cnt <= i_usart_bauddiv;
    end else begin
      r_cnt <= r_cnt - 16'd1;
    end
  end

endmodule
