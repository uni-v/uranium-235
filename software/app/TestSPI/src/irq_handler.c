// See LICENSE for license details.

#include <stdio.h>
#include "uv_sys.h"
#include "uv_irq.h"

extern volatile uint32_t *recv_buf;
extern volatile uint32_t recv_cnt;

void handle_ext_irq() {
    uint32_t ext_irq = LOAD_WORD(REG_IRQ_CLAIM);
    uint32_t spi0_ip = SPI0->ip;
    uint32_t spi0_rx_len = 0;

    if ((ext_irq == SPI0_IRQ) && (spi0_ip & SPI_RX_IRQ_MASK)) {
        spi0_rx_len = SPI0->rxq_len;
        uv_spi_recv_words(SPI0_ID, (uint32_t *) recv_buf + recv_cnt, spi0_rx_len);
        recv_cnt += spi0_rx_len;
    } else {
        printf("Unexpected EXT IRQ: %d\n", ext_irq);
    }
    STORE_WORD(REG_IRQ_CLAIM, ext_irq);
}
