`ifndef USART_ITEM_SV
`define USART_ITEM_SV

class usart_item extends uvm_sequence_item;
  rand bit [8:0] data;
  bit            is_tx; // 1 for TX (DUT to TB), 0 for RX (TB to DUT)

  `uvm_object_utils_begin(usart_item)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(is_tx, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "usart_item");
    super.new(name);
  endfunction
endclass

`endif
