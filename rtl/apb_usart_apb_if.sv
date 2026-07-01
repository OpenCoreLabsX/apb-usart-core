`include "apb_usart_defines.svh"

module apb_usart_apb_if
  import apb_usart_pkg::*;
#(
  parameter int C_APB_DATA_WIDTH = 32,
  parameter int C_APB_ADDR_WIDTH = 8,
  parameter int FIFO_DEPTH       = 16
)
(
  input  logic                        i_usart_pclk,
  input  logic                        i_usart_presetn,

  // APB subordinate interface
  input  logic [C_APB_ADDR_WIDTH-1:0] i_usart_paddr,
  input  logic                        i_usart_psel,
  input  logic                        i_usart_penable,
  input  logic                        i_usart_pwrite,
  input  logic [C_APB_DATA_WIDTH-1:0] i_usart_pwdata,
  input  logic [(C_APB_DATA_WIDTH/8)-1:0] i_usart_pstrb,
  output logic [C_APB_DATA_WIDTH-1:0] o_usart_prdata,
  output logic                        o_usart_pready,
  output logic                        o_usart_pslverr,

  // Control outputs → datapath
  output logic                        o_usart_en,
  output logic                        o_usart_tx_en,
  output logic                        o_usart_rx_en,
  output apb_usart_mode_e             o_usart_mode,
  output apb_usart_parity_e           o_usart_parity,
  output apb_usart_stop_e             o_usart_stop,
  output logic [3:0]                  o_usart_data_bits,
  output logic [15:0]                 o_usart_bauddiv,

  // TX FIFO push
  output logic [8:0]                  o_usart_tx_wr_data,
  output logic                        o_usart_tx_wr_en,
  input  logic                        i_usart_tx_full,
  input  logic                        i_usart_tx_empty,

  // RX FIFO pop
  output logic                        o_usart_rx_rd_en,
  input  logic [8:0]                  i_usart_rx_rd_data,
  input  logic                        i_usart_rx_valid,
  input  logic                        i_usart_rx_full,

  // Status inputs
  input  logic                        i_usart_tx_busy,
  input  logic                        i_usart_tx_done,
  input  logic                        i_usart_rx_done,
  input  logic                        i_usart_parity_err,
  input  logic                        i_usart_frame_err,
  input  logic                        i_usart_overrun_err,

  // FIFO clear (from FIFOCTRL register)
  output logic                        o_usart_fifo_tx_clear,
  output logic                        o_usart_fifo_rx_clear,

  // Interrupt
  output logic                        o_usart_irq
);

  // ── Registers ────────────────────────────────────────────────────────
  logic [31:0] r_ctrl;      // 0x00
  logic [31:0] r_bauddiv;   // 0x08
  logic [31:0] r_irq_en;    // 0x14
  logic [31:0] r_irq_stat;  // 0x18
  logic [31:0] r_fifoctrl;  // 0x1C

  // ── APB handshake ─────────────────────────────────────────────────
  // APB3: pready tied high (single-cycle access)
  logic w_apb_write;
  logic w_apb_read;
  logic w_addr_valid;

  assign o_usart_pready  = 1'b1;
  assign w_apb_write     = i_usart_psel && i_usart_penable && i_usart_pwrite;
  assign w_apb_read      = i_usart_psel && !i_usart_pwrite;

  // Address valid check
  always_comb begin
    unique case (i_usart_paddr)
      APB_USART_ADDR_CTRL,
      APB_USART_ADDR_BAUDDIV,
      APB_USART_ADDR_TXDATA,
      APB_USART_ADDR_RXDATA,
      APB_USART_ADDR_IRQ_EN,
      APB_USART_ADDR_IRQ_STAT,
      APB_USART_ADDR_FIFOCTRL,
      APB_USART_ADDR_STATUS,
      APB_USART_ADDR_VERSION : w_addr_valid = 1'b1;
      default                : w_addr_valid = 1'b0;
    endcase
  end

  assign o_usart_pslverr = (i_usart_psel && i_usart_penable) && !w_addr_valid;

  // ── TX FIFO push on write to TXDATA ──────────────────────────────
  assign o_usart_tx_wr_en   = w_apb_write && (i_usart_paddr == APB_USART_ADDR_TXDATA)
                                          && !i_usart_tx_full;
  assign o_usart_tx_wr_data = {i_usart_pwdata[8], i_usart_pwdata[7:0]};

  // ── RX FIFO pop on read of RXDATA ────────────────────────────────
  assign o_usart_rx_rd_en   = w_apb_read && (i_usart_paddr == APB_USART_ADDR_RXDATA)
                                          && i_usart_rx_valid;

  // ── Control register fields ───────────────────────────────────────
  assign o_usart_en         = r_ctrl[0];
  assign o_usart_tx_en      = r_ctrl[1];
  assign o_usart_rx_en      = r_ctrl[2];
  assign o_usart_mode       = apb_usart_mode_e'(r_ctrl[3]);
  assign o_usart_parity     = apb_usart_parity_e'(r_ctrl[5:4]);
  assign o_usart_stop       = apb_usart_stop_e'(r_ctrl[7:6]);
  assign o_usart_data_bits  = r_ctrl[11:8] + 4'd5;    // 0→5b, 4→9b
  assign o_usart_bauddiv    = r_bauddiv[15:0];
  assign o_usart_fifo_tx_clear = r_fifoctrl[0];
  assign o_usart_fifo_rx_clear = r_fifoctrl[1];
  assign o_usart_irq           = |(r_irq_stat & r_irq_en);

  // ── Write function helper ─────────────────────────────────────────
  function automatic logic [31:0] apply_strb(
    input logic [31:0]              i_old,
    input logic [31:0]              i_new,
    input logic [(C_APB_DATA_WIDTH/8)-1:0] i_strb
  );
    logic [31:0] v;
    begin
      v = i_old;
      for (int b = 0; b < 4; b++) begin
        if (i_strb[b]) v[(b*8) +: 8] = i_new[(b*8) +: 8];
      end
      apply_strb = v;
    end
  endfunction

  // ── Register write ────────────────────────────────────────────────
  always_ff @(posedge i_usart_pclk or negedge i_usart_presetn) begin
    if (!i_usart_presetn) begin
      r_ctrl     <= 32'd0;
      r_bauddiv  <= 32'd26;        // default: ~115200 baud @ 48 MHz
      r_irq_en   <= 32'd0;
      r_irq_stat <= 32'd0;
      r_fifoctrl <= 32'd0;
    end else begin
      // Sticky error capture
      if (i_usart_parity_err)  r_irq_stat[2] <= 1'b1;
      if (i_usart_frame_err)   r_irq_stat[2] <= 1'b1;
      if (i_usart_overrun_err) r_irq_stat[2] <= 1'b1;
      if (i_usart_tx_done)     r_irq_stat[0] <= 1'b1;
      if (i_usart_rx_done)     r_irq_stat[1] <= 1'b1;

      // FIFOCTRL is self-clearing after one cycle
      r_fifoctrl <= 32'd0;

      if (w_apb_write && w_addr_valid) begin
        unique case (i_usart_paddr)
          APB_USART_ADDR_CTRL    : r_ctrl     <= apply_strb(r_ctrl,    i_usart_pwdata, i_usart_pstrb);
          APB_USART_ADDR_BAUDDIV : r_bauddiv  <= apply_strb(r_bauddiv, i_usart_pwdata, i_usart_pstrb);
          APB_USART_ADDR_IRQ_EN  : r_irq_en   <= apply_strb(r_irq_en,  i_usart_pwdata, i_usart_pstrb);
          APB_USART_ADDR_IRQ_STAT: r_irq_stat <= r_irq_stat & ~apply_strb(32'd0, i_usart_pwdata, i_usart_pstrb);
          APB_USART_ADDR_FIFOCTRL: r_fifoctrl <= apply_strb(32'd0,     i_usart_pwdata, i_usart_pstrb);
          default: ;
        endcase
      end
    end
  end

  // ── Read mux ─────────────────────────────────────────────────────
  always_comb begin
    o_usart_prdata = 32'd0;
    unique case (i_usart_paddr)
      APB_USART_ADDR_CTRL    : o_usart_prdata = r_ctrl;
      APB_USART_ADDR_STATUS  : o_usart_prdata = {
                                 24'd0,
                                 i_usart_overrun_err,   // [7]
                                 i_usart_frame_err,     // [6]
                                 i_usart_parity_err,    // [5]
                                 i_usart_rx_full,       // [4]
                                 i_usart_rx_valid,      // [3]
                                 i_usart_tx_full,       // [2]
                                 i_usart_tx_empty,      // [1]
                                 i_usart_tx_busy        // [0]
                               };
      APB_USART_ADDR_BAUDDIV : o_usart_prdata = r_bauddiv;
      APB_USART_ADDR_RXDATA  : o_usart_prdata = {23'd0, i_usart_rx_rd_data};
      APB_USART_ADDR_IRQ_EN  : o_usart_prdata = r_irq_en;
      APB_USART_ADDR_IRQ_STAT: o_usart_prdata = r_irq_stat;
      APB_USART_ADDR_FIFOCTRL: o_usart_prdata = r_fifoctrl;
      APB_USART_ADDR_VERSION : o_usart_prdata = `APB_USART_VERSION;
      default                : o_usart_prdata = 32'd0;
    endcase
  end

endmodule
