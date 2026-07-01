module apb_usart_tb_top;
  import uvm_pkg::*;
  import apb_usart_uvm_pkg::*;

  logic pclk;
  logic presetn;

  // Clock generation
  initial begin
    pclk = 0;
    forever #5 pclk = ~pclk;
  end

  // Reset generation
  initial begin
    presetn = 0;
    #20 presetn = 1;
  end

  // Interfaces
  apb_if apb_vif (pclk, presetn);
  usart_if usart_vif (pclk, presetn);

  // Connect TB USART loopback
  assign usart_vif.rxd = usart_vif.txd;

  // DUT instantiation
  apb_usart_wrapper #(
    .C_APB_DATA_WIDTH (32),
    .C_APB_ADDR_WIDTH (8),
    .FIFO_DEPTH       (16)
  ) u_dut (
    .i_usart_pclk    (pclk),
    .i_usart_presetn (presetn),

    .i_usart_paddr   (apb_vif.paddr),
    .i_usart_psel    (apb_vif.psel),
    .i_usart_penable (apb_vif.penable),
    .i_usart_pwrite  (apb_vif.pwrite),
    .i_usart_pwdata  (apb_vif.pwdata),
    .i_usart_pstrb   (apb_vif.pstrb),
    .o_usart_prdata  (apb_vif.prdata),
    .o_usart_pready  (apb_vif.pready),
    .o_usart_pslverr (apb_vif.pslverr),

    .o_usart_txd     (usart_vif.txd),
    .i_usart_rxd     (usart_vif.rxd),
    .o_usart_sclk    (usart_vif.sclk),
    .o_usart_irq     ()
  );

  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env.m_apb_agent.*", "apb_vif", apb_vif);
    uvm_config_db#(virtual usart_if)::set(null, "uvm_test_top.env.m_usart_agent.*", "usart_vif", usart_vif);

    run_test();
  end
endmodule
