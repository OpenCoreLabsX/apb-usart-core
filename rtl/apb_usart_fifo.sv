module apb_usart_fifo
#(
  parameter int DATA_WIDTH = 8,
  parameter int DEPTH      = 16
)
(
  input  logic                  i_usart_clk,
  input  logic                  i_usart_rst_n,
  input  logic                  i_usart_clear,

  input  logic                  i_usart_wr_en,
  input  logic [DATA_WIDTH-1:0] i_usart_wr_data,
  output logic                  o_usart_full,

  input  logic                  i_usart_rd_en,
  output logic [DATA_WIDTH-1:0] o_usart_rd_data,
  output logic                  o_usart_empty,
  output logic                  o_usart_valid
);

  localparam int PTR_WIDTH = (DEPTH <= 2) ? 1 : $clog2(DEPTH);

  logic [DATA_WIDTH-1:0] r_mem [0:DEPTH-1];
  logic [PTR_WIDTH-1:0]  r_wr_ptr;
  logic [PTR_WIDTH-1:0]  r_rd_ptr;
  logic [PTR_WIDTH:0]    r_count;

  assign o_usart_full    = (r_count == DEPTH[PTR_WIDTH:0]);
  assign o_usart_empty   = (r_count == '0);
  assign o_usart_valid   = !o_usart_empty;
  assign o_usart_rd_data = o_usart_empty ? '0 : r_mem[r_rd_ptr];

  always_ff @(posedge i_usart_clk or negedge i_usart_rst_n) begin
    if (!i_usart_rst_n) begin
      r_wr_ptr <= '0;
      r_rd_ptr <= '0;
      r_count  <= '0;
    end else if (i_usart_clear) begin
      r_wr_ptr <= '0;
      r_rd_ptr <= '0;
      r_count  <= '0;
    end else begin
      if (i_usart_wr_en && !o_usart_full) begin
        r_mem[r_wr_ptr] <= i_usart_wr_data;
        r_wr_ptr        <= r_wr_ptr + {{(PTR_WIDTH-1){1'b0}}, 1'b1};
      end

      if (i_usart_rd_en && !o_usart_empty) begin
        r_rd_ptr <= r_rd_ptr + {{(PTR_WIDTH-1){1'b0}}, 1'b1};
      end

      unique case ({i_usart_wr_en && !o_usart_full, i_usart_rd_en && !o_usart_empty})
        2'b10:   r_count <= r_count + {{PTR_WIDTH{1'b0}}, 1'b1};
        2'b01:   r_count <= r_count - {{PTR_WIDTH{1'b0}}, 1'b1};
        default: ;
      endcase
    end
  end

endmodule
