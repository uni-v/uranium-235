// See LICENSE for license details.

#include "uv_sys.h"

//************************************************************
// Global variables.
static spi_type *SPIs[2] = {SPI0, SPI1};

//************************************************************
// Timer operations.
void uv_tmr_init(bool auto_clr, uint32_t clk_div, uint64_t cmp) {
    uint32_t tmr_cfg = SLC->tmr_cfg;
    if (auto_clr) {
        tmr_cfg |= SLC_TMR_CLR_EN_MASK;
    } else {
        tmr_cfg &= ~SLC_TMR_CLR_EN_MASK;
    }
    tmr_cfg &= ~SLC_TMR_CLK_DIV_MASK;
    tmr_cfg |= (clk_div << SLC_TMR_CLK_DIV_OFFSET) & SLC_TMR_CLK_DIV_MASK;
    SLC->tmr_cfg = tmr_cfg;

    SLC->tmr_cmp = cmp & 0xFFFFFFFFUL;
    SLC->tmr_cmph = cmp >> 32;
}

void uv_tmr_start() {
    SLC->tmr_cfg |= SLC_TMR_CNT_EN_MASK;
}

void uv_tmr_stop() {
    SLC->tmr_cfg &= ~SLC_TMR_CNT_EN_MASK;
}

void uv_tmr_set_val(uint64_t val) {
    bool has_started = SLC->tmr_cfg & SLC_TMR_CNT_EN_MASK;

    if (has_started) {
        uv_tmr_stop();
    }
    SLC->tmr_val = val & 0xFFFFFFFFUL;
    SLC->tmr_valh = val >> 32;
    if (has_started) {
        uv_tmr_start();
    }
}

uint64_t uv_tmr_get_val() {
    uint32_t low;
    uint32_t high;

    while (true) {
        high = SLC->tmr_valh;
        low = SLC->tmr_val;
        if (high == SLC->tmr_valh) {
            break;
        }
    }

    return ((uint64_t) high << 32) | low;
}

//************************************************************
// UART operations.
void uv_uart_init(bool tx_en, bool rx_en, uint32_t baud_rate) {
    uint32_t glb_cfg = 0;
    uint32_t clk_div = 0;
    uint32_t endian = UART_DEFAULT_ENDIAN;
    uint32_t nbits = UART_DEFAULT_NUM_BITS - 5;
    uint32_t nstop = UART_DEFAULT_NUM_STOPS - 1;

    // Enabling TX & RX.
    if (tx_en) glb_cfg |= UART_TX_EN_MASK;
    if (rx_en) glb_cfg |= UART_RX_EN_MASK;

    // Set endian.
    glb_cfg &= ~UART_ENDIAN_MASK;
    glb_cfg |= (endian << UART_ENDIAN_OFFSET) & UART_ENDIAN_MASK;

    // Set unit bits.
    glb_cfg &= ~UART_NBITS_MASK;
    glb_cfg |= (nbits << UART_NBITS_OFFSET) & UART_NBITS_MASK;

    // Set stops.
    glb_cfg &= ~UART_NSTOP_MASK;
    glb_cfg |= (nstop << UART_NSTOP_OFFSET) & UART_NSTOP_MASK;

    // Set clock divider according to baud rate.
    clk_div = MAIN_CLK_FREQ / baud_rate;
    if ((MAIN_CLK_FREQ % baud_rate) > (baud_rate >> 1)) {
        clk_div++;
    }
    glb_cfg &= ~UART_CLK_DIV_MASK;
    glb_cfg |= (clk_div << UART_CLK_DIV_OFFSET) & UART_CLK_DIV_MASK;

    UART->glb_cfg = glb_cfg;
}

void uv_uart_set_parity(bool parity_en, uint32_t parity_type) {
    uint32_t glb_cfg = UART->glb_cfg;
    if (parity_en) {
        glb_cfg &= ~UART_PARITY_TYPE_MASK;
        glb_cfg |= (parity_type << UART_PARITY_TYPE_OFFSET) & UART_PARITY_TYPE_MASK;
        glb_cfg |= UART_PARITY_EN_MASK;
    }
}

void uv_uart_set_tx_irq(bool tx_ie, uint32_t tx_th) {
    if (tx_ie) {
        if (tx_th < UART->txq_cap) {
            UART->tx_irq_th = tx_th;
        } else {
            UART->tx_irq_th = 0;
        }
        UART->ie |= UART_TX_IRQ_MASK;
    } else {
        UART->ie &= ~UART_TX_IRQ_MASK;
    }
}

void uv_uart_set_rx_irq(bool rx_ie, uint32_t rx_th) {
    if (rx_ie) {
        if ((rx_th > 0) && (rx_th <= UART->rxq_cap)) {
            UART->rx_irq_th = rx_th;
        } else {
            UART->rx_irq_th = UART->rxq_cap;
        }
        UART->ie |= UART_RX_IRQ_MASK;
    } else {
        UART->ie &= ~UART_RX_IRQ_MASK;
    }
}

void uv_uart_send_data(uint8_t *buf, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        while (UART->txq_len == UART->txq_cap) {
            ;
        }
        UART->txq_dat = buf[i];
    }
}

void uv_uart_recv_data(uint8_t *buf, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        while (UART->rxq_len == 0) {
            ;
        }
        buf[i] = UART->rxq_dat;
    }
}

//************************************************************
// SPI operations.
void uv_spi_init(uint32_t id, uint32_t cs_mask, bool rx_en, spi_cfg *cfg) {
    SPIs[id]->glb_cfg = *((uint32_t *) cfg);
    SPIs[id]->cs_idle = SPI_DEFAULT_CS_IDLE;
    SPIs[id]->cs_mask = cs_mask & 0xF;
    SPIs[id]->recv_en = rx_en;
}

void uv_spi_set_tx_irq(uint32_t id, bool tx_ie, uint32_t tx_th) {
    if (tx_ie) {
        if (tx_th < SPIs[id]->txq_cap) {
            SPIs[id]->tx_irq_th = tx_th;
        } else {
            SPIs[id]->tx_irq_th = 0;
        }
        SPIs[id]->ie |= SPI_TX_IRQ_MASK;
    } else {
        SPIs[id]->ie &= ~SPI_TX_IRQ_MASK;
    }
}

void uv_spi_set_rx_irq(uint32_t id, bool rx_ie, uint32_t rx_th) {
    if (rx_ie) {
        if ((rx_th > 0) && (rx_th <= SPIs[id]->rxq_cap)) {
            SPIs[id]->rx_irq_th = rx_th;
        } else {
            SPIs[id]->rx_irq_th = SPIs[id]->rxq_cap;
        }
        SPIs[id]->ie |= SPI_RX_IRQ_MASK;
    } else {
        SPIs[id]->ie &= ~SPI_RX_IRQ_MASK;
    }
}

void uv_spi_send_bytes(uint32_t id, uint8_t *buf, size_t len) {
    uint32_t data;
    for (size_t i = 0; i < len; ++i) {
        data = buf[i];
        while (SPIs[id]->txq_len == SPIs[id]->txq_cap) {
            ;
        }
        SPIs[id]->txq_dat = data;
    }
}

void uv_spi_recv_bytes(uint32_t id, uint8_t *buf, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        while (SPIs[id]->rxq_len == 0) {
            ;
        }
        buf[i] = (uint8_t) SPIs[id]->rxq_dat;
    }
}

void uv_spi_send_halfs(uint32_t id, uint16_t *buf, size_t len) {
    uint32_t data;
    for (size_t i = 0; i < len; ++i) {
        data = buf[i];
        while (SPIs[id]->txq_len == SPIs[id]->txq_cap) {
            ;
        }
        SPIs[id]->txq_dat = data;
    }
}

void uv_spi_recv_halfs(uint32_t id, uint16_t *buf, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        while (SPIs[id]->rxq_len == 0) {
            ;
        }
        buf[i] = (uint16_t) SPIs[id]->rxq_dat;
    }
}

void uv_spi_send_words(uint32_t id, uint32_t *buf, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        while (SPIs[id]->txq_len == SPIs[id]->txq_cap) {
            ;
        }
        SPIs[id]->txq_dat = buf[i];
    }
}

void uv_spi_recv_words(uint32_t id, uint32_t *buf, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        while (SPIs[id]->rxq_len == 0) {
            ;
        }
        buf[i] = SPIs[id]->rxq_dat;
    }
}
