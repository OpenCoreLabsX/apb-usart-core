`ifndef USART_IF_SV
`define USART_IF_SV

interface usart_if (input logic clk, input logic rst_n);
  logic txd;
  logic rxd;
  logic sclk;

  modport dut (
    output txd, sclk,
    input  rxd
  );

  modport tb (
    input  txd, sclk,
    output rxd
  );
endinterface

`endif
