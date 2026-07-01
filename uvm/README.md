# APB USART UVM Verification

This directory contains the UVM testbench for `apb_usart_wrapper` via APB interface.

## Directory tree

```text
uvm/
|-- agent/
|   |-- apb_agent.sv
|   |-- apb_item.sv
|   |-- apb_sequencer.sv
|   |-- usart_agent.sv
|   |-- usart_item.sv
|-- driver/
|   |-- apb_driver.sv
|   |-- usart_driver.sv
|-- env/
|   `-- apb_usart_env.sv
|-- monitor/
|   |-- apb_monitor.sv
|   |-- usart_monitor.sv
|-- scoreboard/
|   `-- apb_usart_scoreboard.sv
|-- sequences/
|   |-- apb_usart_base_seq.sv
|   `-- apb_usart_smoke_seq.sv
|-- tb/
|   |-- apb_if.sv
|   |-- usart_if.sv
|   |-- apb_usart_tb_top.sv
|   `-- apb_usart_uvm_pkg.sv
|-- tests/
|   |-- apb_usart_base_test.sv
|   `-- apb_usart_smoke_test.sv
```

## Questa example

Chay tu thu muc `apb-usart-core`:

```sh
make compile
make run
```

Chay test rieng:

```sh
make run UVM_TEST=apb_usart_smoke_test
```
