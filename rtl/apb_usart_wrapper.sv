`include "apb_usart_defines.svh"

module apb_usart_wrapper
  import apb_usart_pkg::*;
#(
  parameter int C_APB_DATA_WIDTH = 32,
  parameter int C_APB_ADDR_WIDTH = 8,
  parameter int FIFO_DEPTH       = 16
)
(
  input  logic                            i_usart_pclk,
  input  logic                            i_usart_presetn,

  // APB subordinate port
  input  logic [C_APB_ADDR_WIDTH-1:0]    i_usart_paddr,
  input  logic                            i_usart_psel,
  input  logic                            i_usart_penable,
  input  logic                            i_usart_pwrite,
  input  logic [C_APB_DATA_WIDTH-1:0]    i_usart_pwdata,
  input  logic [(C_APB_DATA_WIDTH/8)-1:0] i_usart_pstrb,
  output logic [C_APB_DATA_WIDTH-1:0]    o_usart_prdata,
  output logic                            o_usart_pready,
  output logic                            o_usart_pslverr,

  // Serial I/O
  output logic                            o_usart_txd,
  input  logic                            i_usart_rxd,
  output logic                            o_usart_sclk,  // USART sync mode

  // Interrupt
  output logic                            o_usart_irq
);

  // ── Internal wires ──────────────────────────────────────────────────
  logic                  w_en;
  logic                  w_tx_en;
  logic                  w_rx_en;
  apb_usart_mode_e       w_mode;
  apb_usart_parity_e     w_parity;
  apb_usart_stop_e       w_stop;
  logic [3:0]            w_data_bits;
  logic [15:0]           w_bauddiv;

  logic                  w_baud_tick;
  logic                  w_baud_tick_mid;

  logic [8:0]            w_tx_wr_data;
  logic                  w_tx_wr_en;
  logic                  w_tx_full;
  logic                  w_tx_empty;
  logic                  w_tx_busy;
  logic                  w_tx_done;

  logic                  w_rx_rd_en;
  logic [8:0]            w_rx_rd_data;
  logic                  w_rx_valid;
  logic                  w_rx_full;
  logic                  w_rx_done;

  logic                  w_parity_err;
  logic                  w_frame_err;
  logic                  w_overrun_err;

  logic                  w_fifo_tx_clear;
  logic                  w_fifo_rx_clear;

  // ── Baud rate generator ─────────────────────────────────────────────
  apb_usart_baud_gen u_baud_gen (
    .i_usart_clk       (i_usart_pclk),
    .i_usart_rst_n     (i_usart_presetn),
    .i_usart_en        (w_en),
    .i_usart_bauddiv   (w_bauddiv),
    .o_usart_tick      (w_baud_tick),
    .o_usart_tick_mid  (w_baud_tick_mid)
  );

  // ── APB register interface ─────────────────────────────────────────
  apb_usart_apb_if #(
    .C_APB_DATA_WIDTH (C_APB_DATA_WIDTH),
    .C_APB_ADDR_WIDTH (C_APB_ADDR_WIDTH),
    .FIFO_DEPTH       (FIFO_DEPTH)
  ) u_apb_if (
    .i_usart_pclk         (i_usart_pclk),
    .i_usart_presetn      (i_usart_presetn),
    .i_usart_paddr        (i_usart_paddr),
    .i_usart_psel         (i_usart_psel),
    .i_usart_penable      (i_usart_penable),
    .i_usart_pwrite       (i_usart_pwrite),
    .i_usart_pwdata       (i_usart_pwdata),
    .i_usart_pstrb        (i_usart_pstrb),
    .o_usart_prdata       (o_usart_prdata),
    .o_usart_pready       (o_usart_pready),
    .o_usart_pslverr      (o_usart_pslverr),
    .o_usart_en           (w_en),
    .o_usart_tx_en        (w_tx_en),
    .o_usart_rx_en        (w_rx_en),
    .o_usart_mode         (w_mode),
    .o_usart_parity       (w_parity),
    .o_usart_stop         (w_stop),
    .o_usart_data_bits    (w_data_bits),
    .o_usart_bauddiv      (w_bauddiv),
    .o_usart_tx_wr_data   (w_tx_wr_data),
    .o_usart_tx_wr_en     (w_tx_wr_en),
    .i_usart_tx_full      (w_tx_full),
    .i_usart_tx_empty     (w_tx_empty),
    .o_usart_rx_rd_en     (w_rx_rd_en),
    .i_usart_rx_rd_data   (w_rx_rd_data),
    .i_usart_rx_valid     (w_rx_valid),
    .i_usart_rx_full      (w_rx_full),
    .i_usart_tx_busy      (w_tx_busy),
    .i_usart_tx_done      (w_tx_done),
    .i_usart_rx_done      (w_rx_done),
    .i_usart_parity_err   (w_parity_err),
    .i_usart_frame_err    (w_frame_err),
    .i_usart_overrun_err  (w_overrun_err),
    .o_usart_fifo_tx_clear(w_fifo_tx_clear),
    .o_usart_fifo_rx_clear(w_fifo_rx_clear),
    .o_usart_irq          (o_usart_irq)
  );

  // ── TX datapath ─────────────────────────────────────────────────────
  apb_usart_tx #(
    .FIFO_DEPTH (FIFO_DEPTH)
  ) u_tx (
    .i_usart_clk        (i_usart_pclk),
    .i_usart_rst_n      (i_usart_presetn),
    .i_usart_en         (w_en),
    .i_usart_tx_en      (w_tx_en),
    .i_usart_mode       (w_mode),
    .i_usart_parity     (w_parity),
    .i_usart_stop       (w_stop),
    .i_usart_data_bits  (w_data_bits),
    .i_usart_baud_tick  (w_baud_tick),
    .i_usart_wr_data    (w_tx_wr_data),
    .i_usart_wr_en      (w_tx_wr_en),
    .o_usart_tx_full    (w_tx_full),
    .o_usart_tx_empty   (w_tx_empty),
    .o_usart_txd        (o_usart_txd),
    .o_usart_sclk       (o_usart_sclk),
    .o_usart_busy       (w_tx_busy),
    .o_usart_done       (w_tx_done)
  );

  // ── RX datapath ─────────────────────────────────────────────────────
  apb_usart_rx #(
    .FIFO_DEPTH (FIFO_DEPTH)
  ) u_rx (
    .i_usart_clk          (i_usart_pclk),
    .i_usart_rst_n        (i_usart_presetn),
    .i_usart_en           (w_en),
    .i_usart_rx_en        (w_rx_en),
    .i_usart_parity       (w_parity),
    .i_usart_stop         (w_stop),
    .i_usart_data_bits    (w_data_bits),
    .i_usart_baud_tick    (w_baud_tick),
    .i_usart_baud_tick_mid(w_baud_tick_mid),
    .i_usart_rxd          (i_usart_rxd),
    .i_usart_rd_en        (w_rx_rd_en),
    .o_usart_rd_data      (w_rx_rd_data),
    .o_usart_rx_full      (w_rx_full),
    .o_usart_rx_valid     (w_rx_valid),
    .o_usart_parity_err   (w_parity_err),
    .o_usart_frame_err    (w_frame_err),
    .o_usart_overrun_err  (w_overrun_err),
    .o_usart_rx_done      (w_rx_done)
  );

endmodule
