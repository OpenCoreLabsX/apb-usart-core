package apb_usart_pkg;

  // ── Mode ─────────────────────────────────────────────────────────────
  typedef enum logic {
    USART_MODE_ASYNC = 1'b0,   // UART asynchronous
    USART_MODE_SYNC  = 1'b1    // USART synchronous (SCLK driven by TX)
  } apb_usart_mode_e;

  // ── Parity ───────────────────────────────────────────────────────────
  typedef enum logic [1:0] {
    USART_PARITY_NONE  = 2'd0,
    USART_PARITY_ODD   = 2'd1,
    USART_PARITY_EVEN  = 2'd2
  } apb_usart_parity_e;

  // ── Stop bits ────────────────────────────────────────────────────────
  typedef enum logic [1:0] {
    USART_STOP_1   = 2'd0,    // 1   stop bit
    USART_STOP_1P5 = 2'd1,    // 1.5 stop bits
    USART_STOP_2   = 2'd2     // 2   stop bits
  } apb_usart_stop_e;

  // ── TX FSM ───────────────────────────────────────────────────────────
  typedef enum logic [2:0] {
    USART_TX_IDLE,
    USART_TX_START,
    USART_TX_DATA,
    USART_TX_PARITY,
    USART_TX_STOP,
    USART_TX_STOP2,
    USART_TX_DONE
  } apb_usart_tx_state_e;

  // ── RX FSM ───────────────────────────────────────────────────────────
  typedef enum logic [2:0] {
    USART_RX_IDLE,
    USART_RX_START,
    USART_RX_DATA,
    USART_RX_PARITY,
    USART_RX_STOP,
    USART_RX_DONE
  } apb_usart_rx_state_e;

  // ── Register offsets (APB byte address) ──────────────────────────────
  localparam logic [7:0] APB_USART_ADDR_CTRL     = 8'h00; // RW control
  localparam logic [7:0] APB_USART_ADDR_STATUS   = 8'h04; // RO status
  localparam logic [7:0] APB_USART_ADDR_BAUDDIV  = 8'h08; // RW baud divisor
  localparam logic [7:0] APB_USART_ADDR_TXDATA   = 8'h0C; // WO TX FIFO push
  localparam logic [7:0] APB_USART_ADDR_RXDATA   = 8'h10; // RO RX FIFO pop
  localparam logic [7:0] APB_USART_ADDR_IRQ_EN   = 8'h14; // RW IRQ enable
  localparam logic [7:0] APB_USART_ADDR_IRQ_STAT = 8'h18; // RW1C IRQ status
  localparam logic [7:0] APB_USART_ADDR_FIFOCTRL = 8'h1C; // RW FIFO control
  localparam logic [7:0] APB_USART_ADDR_VERSION  = 8'h20; // RO version

  // ── CTRL register bit positions ───────────────────────────────────────
  // [0]    : USART enable
  // [1]    : TX enable
  // [2]    : RX enable
  // [3]    : mode  (0=async, 1=sync)
  // [5:4]  : parity (00=none,01=odd,10=even)
  // [7:6]  : stop bits (00=1, 01=1.5, 10=2)
  // [10:8] : data bits - 5 = number of data bits (000=5b..100=9b)
  // [11]   : SCLK polarity (USART sync mode only)
  // [12]   : SCLK phase    (USART sync mode only)

  // ── STATUS register bit positions ─────────────────────────────────────
  // [0]  : TX busy
  // [1]  : TX FIFO empty
  // [2]  : TX FIFO full
  // [3]  : RX data valid (FIFO not empty)
  // [4]  : RX FIFO full
  // [5]  : parity error (sticky, cleared by IRQ_STAT write)
  // [6]  : framing error (sticky)
  // [7]  : overrun error (sticky)

  // ── IRQ_EN / IRQ_STAT bit positions ──────────────────────────────────
  // [0]  : TX done (shift register empty)
  // [1]  : RX valid (byte received)
  // [2]  : error   (parity | framing | overrun)

endpackage
