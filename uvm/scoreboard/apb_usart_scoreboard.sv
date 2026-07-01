`ifndef APB_USART_SCOREBOARD_SV
`define APB_USART_SCOREBOARD_SV

class apb_usart_scoreboard extends uvm_scoreboard;
  uvm_analysis_imp #(apb_item, apb_usart_scoreboard) apb_export;

  bit [8:0] tx_queue[$];

  `uvm_component_utils(apb_usart_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    apb_export = new("apb_export", this);
  endfunction

  virtual function void write(apb_item item);
    // Address 0x0C is TXDATA, 0x10 is RXDATA
    if (item.is_write && item.addr == 32'h0C) begin
      `uvm_info("SCB", $sformatf("TX Data written: %0h", item.data), UVM_LOW)
      tx_queue.push_back(item.data[8:0]);
    end else if (!item.is_write && item.addr == 32'h10) begin
      bit [8:0] expected_data;
      if (tx_queue.size() > 0) begin
        expected_data = tx_queue.pop_front();
        if (item.data[8:0] == expected_data) begin
          `uvm_info("SCB", $sformatf("MATCH! RX Data read: %0h", item.data), UVM_LOW)
        end else begin
          `uvm_error("SCB", $sformatf("MISMATCH! RX Data read: %0h, Expected: %0h", item.data, expected_data))
        end
      end else begin
        `uvm_info("SCB", $sformatf("RX Data read without expected TX in queue: %0h", item.data), UVM_LOW)
      end
    end
  endfunction
endclass

`endif
