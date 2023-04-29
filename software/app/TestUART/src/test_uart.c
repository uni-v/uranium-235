// See LICENSE for license details.

#include <stdio.h>
#include "uv_sys.h"
#include "uv_irq.h"

#define TEST_NUM 16

volatile uint8_t data_buf[TEST_NUM * 2];
volatile uint8_t *send_buf = data_buf;
volatile uint8_t *recv_buf = data_buf + TEST_NUM;
volatile uint32_t recv_cnt = 0;

int main() {
    uint32_t irq_priority = 7;
    uint32_t irq_trigger = 0;
    uint8_t data_byte = 0;

    // Config UART.
    uv_uart_init(true, true, UART_BAUD_RATE_115200);
    printf("UART config done!\n");

    // Config interrupt.
    uv_enable_glb_irq();
    uv_enable_ext_irq();
    uv_config_ext_irq(UART_IRQ, irq_priority, irq_trigger);
    uv_set_target_threshold(0);
    SET_EXT_IE(UART_IRQ);

    UART->rx_irq_th = 4;
    UART->ie = 0x2;
    printf("IRQs config done!\n");

    // Send data to TX.
    for (int i = 0; i < TEST_NUM; ++i) {
        data_byte++;
        uv_uart_send_data(&data_byte, 1);
        send_buf[i] = data_byte;
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
            printf("PASS, 0x%02x\n", recv_buf[i]);
        } else {
            fail_cnt++;
            printf("FAIL, 0x%02x vs. 0x%02x\n", send_buf[i], recv_buf[i]);
        }
    }
    if (fail_cnt > 0) {
        printf("Data check failed!\n");
    } else {
        printf("Data check passed!\n");
    }

    return 0;
}
