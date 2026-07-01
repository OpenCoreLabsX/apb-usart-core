`ifndef APB_USART_ENV_SV
`define APB_USART_ENV_SV

class apb_usart_env extends uvm_env;
  apb_agent            m_apb_agent;
  usart_agent          m_usart_agent;
  apb_usart_scoreboard m_scoreboard;

  `uvm_component_utils(apb_usart_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_apb_agent   = apb_agent::type_id::create("m_apb_agent", this);
    m_usart_agent = usart_agent::type_id::create("m_usart_agent", this);
    m_scoreboard  = apb_usart_scoreboard::type_id::create("m_scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    m_apb_agent.monitor.ap.connect(m_scoreboard.apb_export);
  endfunction
endclass

`endif
