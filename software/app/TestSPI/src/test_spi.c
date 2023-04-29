// See LICENSE for license details.

#include <stdio.h>
#include "uv_sys.h"
#include "uv_irq.h"

#define TEST_NUM 16

volatile uint32_t data_buf[TEST_NUM * 2];
volatile uint32_t *send_buf = data_buf;
volatile uint32_t *recv_buf = data_buf + TEST_NUM;
volatile uint32_t recv_cnt = 0;

int main() {
    uint32_t irq_priority = 7;
    uint32_t irq_trigger = 0;
    uint32_t data_word = 1;

    // Config SPI.
    spi_cfg cfg;
    cfg.cpol = 0;
    cfg.cpha = 0;
    cfg.endian = SPI_LITTLE_ENDIAN;
    cfg.unit_len = SPI_UNIT_LEN_32BITS;
    cfg.sck_dly = 4;    // start sck after (sck_dly + 1) cycles.
    cfg.clk_div = 4;    // sck_freq = main_freq / (2 * (clk_div + 1))
    uv_spi_init(SPI0_ID, 0x1, true, &cfg);
    printf("SPI0 config done!\n");

    // Config interrupt.
    uv_enable_glb_irq();
    uv_enable_ext_irq();
    uv_config_ext_irq(SPI0_IRQ, irq_priority, irq_trigger);
    uv_set_target_threshold(0);
    SET_EXT_IE(SPI0_IRQ);

    uv_spi_set_rx_irq(0, true, 4);
    printf("IRQs config done!\n");

    // Send data to slave.
    for (int i = 0; i < TEST_NUM; ++i) {
        uv_spi_send_words(SPI0_ID, &data_word, 1);
        send_buf[i] = data_word;
        data_word <<= 1;
        if (data_word == 0) {
            data_word = 1;
        }
    }
    printf("Data sent done (TN = %d, RN = %d)!\n", TEST_NUM, recv_cnt);

    // Wait for recv done.
    while (recv_cnt < TEST_NUM) {
        ;
    }
    printf("Data recv done (TN = %d, RN = %d)!\n", TEST_NUM, recv_cnt);

    uint32_t fail_cnt = 0;
    for (int i = 0; i < TEST_NUM; ++i) {
        printf("Data %d: ", i);
        if (send_buf[i] == recv_buf[i]) {
            printf("PASS, 0x%x\n", recv_buf[i]);
        } else {
            fail_cnt++;
            printf("FAIL, 0x%x vs. 0x%x\n", send_buf[i], recv_buf[i]);
        }
    }
    if (fail_cnt > 0) {
        printf("Data check failed!\n");
    } else {
        printf("Data check passed!\n");
    }

    return 0;
}
