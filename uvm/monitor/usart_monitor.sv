`ifndef USART_MONITOR_SV
`define USART_MONITOR_SV

class usart_monitor extends uvm_monitor;
  virtual usart_if vif;
  uvm_analysis_port #(usart_item) ap;

  `uvm_component_utils(usart_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual usart_if)::get(this, "", "usart_vif", vif)) begin
      `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
    end
  endfunction

  task run_phase(uvm_phase phase);
    // Placeholder: Full serial decoding (baud rate recovery) would go here.
    // For smoke testing, loopback is used and verified via APB reads.
  endtask
endclass

`endif
