`ifndef APB_USART_SMOKE_SEQ_SV
`define APB_USART_SMOKE_SEQ_SV

class apb_usart_smoke_seq extends apb_usart_base_seq;
  `uvm_object_utils(apb_usart_smoke_seq)

  function new(string name = "apb_usart_smoke_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] rdata;
    
    // Read Version
    read_reg(32'h20, rdata);
    `uvm_info("SEQ", $sformatf("USART Version: %08x", rdata), UVM_LOW)

    // Configure BAUDDIV (e.g. div by 10)
    write_reg(32'h08, 32'd10);
    
    // Enable USART, TX, RX, Async, No Parity, 1 Stop Bit, 8 Data Bits
    // CTRL: [0] EN=1, [1] TX_EN=1, [2] RX_EN=1, [3] MODE=0, [5:4] PAR=0, [7:6] STOP=0, [10:8] DATA=3 (8 bits)
    write_reg(32'h00, 32'h00000307);

    // Write a byte to TXDATA
    write_reg(32'h0C, 32'h000000A5);

    // Poll STATUS to see if RX Valid is set (bit 3)
    do begin
      #1000;
      read_reg(32'h04, rdata);
    end while ((rdata & 32'h08) == 0);

    `uvm_info("SEQ", $sformatf("STATUS: %08x", rdata), UVM_LOW)

    // Read RXDATA
    read_reg(32'h10, rdata);
    `uvm_info("SEQ", $sformatf("RXDATA: %08x", rdata), UVM_LOW)
  endtask
endclass

`endif
