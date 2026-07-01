`ifndef USART_AGENT_SV
`define USART_AGENT_SV

class usart_agent extends uvm_agent;
  usart_monitor monitor;

  `uvm_component_utils(usart_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = usart_monitor::type_id::create("monitor", this);
  endfunction
endclass

`endif
