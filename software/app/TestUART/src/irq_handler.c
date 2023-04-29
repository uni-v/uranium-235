// See LICENSE for license details.

#include <stdio.h>
#include "uv_sys.h"
#include "uv_irq.h"

extern volatile uint8_t *recv_buf;
extern volatile uint32_t recv_cnt;

void handle_ext_irq() {
    uint32_t ext_irq = LOAD_WORD(REG_IRQ_CLAIM);
    uint32_t uart_ip = UART->ip;
    uint32_t uart_rx_len = 0;

    if ((ext_irq == UART_IRQ) && (uart_ip & UART_RX_IRQ_MASK)) {
        uart_rx_len = UART->rxq_len;
        uv_uart_recv_data((uint8_t *) recv_buf + recv_cnt, uart_rx_len);
        recv_cnt += uart_rx_len;
    } else {
        printf("Unexpected EXT IRQ: %d\n", ext_irq);
    }
    STORE_WORD(REG_IRQ_CLAIM, ext_irq);
}
