<div align="center">

# GitHub Readme Stats

Get dynamically generated GitHub stats on your READMEs!

<p>
  <img src="https://img.shields.io/badge/Test-failing-red?style=flat&logo=github" alt="Test">
  <img src="https://img.shields.io/badge/contributors-302-brightgreen?style=flat" alt="Contributors">
  <img src="https://img.shields.io/badge/codecov-97%25-brightgreen?style=flat&logo=codecov" alt="Codecov">
  <img src="https://img.shields.io/badge/issues-167%20open-blue?style=flat" alt="Issues">
  <img src="https://img.shields.io/badge/pull%20requests-119%20open-blue?style=flat" alt="Pull Requests">
  <img src="https://img.shields.io/badge/openssf%20scorecard-6.5-yellow?style=flat" alt="OpenSSF Scorecard">
</p>

[![Powered by Vercel](https://img.shields.io/badge/Powered%20by-Vercel-black?style=for-the-badge&logo=vercel)](https://vercel.com)

</div>

---

# APB USART IP Core

APB USART controller RTL written in SystemVerilog for MCU, SoC, and RISC-V based systems.

## Features

| Item | Description |
| --- | --- |
| Control interface | 32-bit APB (Advanced Peripheral Bus) register interface |
| Modes | Asynchronous (UART) and Synchronous (USART) |
| Configurability | Programmable data bits (5-8), stop bits (1, 1.5, 2), and parity (Odd, Even, None) |
| Clocking | Configurable fractional/integer baud rate divider |
| Data path | Independent parameterized TX and RX FIFOs (Default depth 16) |
| Glitch filter | 3-stage majority voter for superior RX noise immunity |
| Interrupts | Transfer done, RX valid, parity error, framing error, and overrun error |
| Status flags | TX/RX full, TX/RX empty, TX busy, RX valid |

## Registers

| Address | Name | Description |
| --- | --- | --- |
| `0x00` | `CTRL` | Global, TX, and RX enable bits, mode, parity, stop bits, data bits |
| `0x04` | `STATUS` | Read-only flags for full/empty conditions and busy status |
| `0x08` | `BAUDDIV` | Base clock divider for generating baud ticks |
| `0x0C` | `TXDATA` | Writes push data directly to the TX FIFO |
| `0x10` | `RXDATA` | Reads pop data directly from the RX FIFO |
| `0x14` | `IRQ_EN` | Mask to enable/disable specific interrupt sources |
| `0x18` | `IRQ_STAT` | Interrupt status (Write 1 to clear) with loss-of-interrupt protection |
| `0x1C` | `FIFOCTRL` | Strobe bits to clear TX or RX FIFOs |
| `0x20` | `VERSION` | Read-only IP version identifier |

## Repository Structure

```text
.
|-- inc/        Global defines
|-- rtl/        Synthesizable APB USART RTL
|-- docs/       GitHub Pages documentation setup
|-- uvm/        UVM verification testbench environment
|-- filelist.f  RTL compile filelist
`-- Makefile    Verilator lint and ModelSim UVM run targets
```

## Build & Test

```sh
# Lint RTL using Verilator
make lint

# Run UVM smoke test using ModelSim/Questasim
make run UVM_TEST=apb_usart_smoke_test
```
