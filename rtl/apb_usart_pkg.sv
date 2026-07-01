package apb_usart_pkg;

  typedef enum logic {
    USART_MODE_ASYNC = 1'b0,
    USART_MODE_SYNC  = 1'b1
  } apb_usart_mode_e;

  typedef enum logic [1:0] {
    USART_PARITY_NONE = 2'd0,
    USART_PARITY_ODD  = 2'd1,
    USART_PARITY_EVEN = 2'd2
  } apb_usart_parity_e;

  typedef enum logic [1:0] {
    USART_STOP_1   = 2'd0,
    USART_STOP_1P5 = 2'd1,
    USART_STOP_2   = 2'd2
  } apb_usart_stop_e;

  typedef enum logic [2:0] {
    USART_TX_IDLE,
    USART_TX_START,
    USART_TX_DATA,
    USART_TX_PARITY,
    USART_TX_STOP,
    USART_TX_STOP2,
    USART_TX_DONE
  } apb_usart_tx_state_e;

  typedef enum logic [2:0] {
    USART_RX_IDLE,
    USART_RX_START,
    USART_RX_DATA,
    USART_RX_PARITY,
    USART_RX_STOP,
    USART_RX_DONE
  } apb_usart_rx_state_e;

  localparam logic [7:0] APB_USART_ADDR_CTRL     = 8'h00;
  localparam logic [7:0] APB_USART_ADDR_STATUS   = 8'h04;
  localparam logic [7:0] APB_USART_ADDR_BAUDDIV  = 8'h08;
  localparam logic [7:0] APB_USART_ADDR_TXDATA   = 8'h0C;
  localparam logic [7:0] APB_USART_ADDR_RXDATA   = 8'h10;
  localparam logic [7:0] APB_USART_ADDR_IRQ_EN   = 8'h14;
  localparam logic [7:0] APB_USART_ADDR_IRQ_STAT = 8'h18;
  localparam logic [7:0] APB_USART_ADDR_FIFOCTRL = 8'h1C;
  localparam logic [7:0] APB_USART_ADDR_VERSION  = 8'h20;

endpackage
