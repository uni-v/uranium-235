// See LICENSE for license details.

#ifndef __UV_SYS__
#define __UV_SYS__

#include <stdint.h>
#include <stdbool.h>
#include "encoding.h"

//************************************************************
// System parameters.
#define MAIN_CLK_FREQ           100000000

//************************************************************
// Basic load-store functions.
#define STORE_BYTE(A, D)        (*(volatile uint8_t  *) (A) = (D))
#define STORE_HALF(A, D)        (*(volatile uint16_t *) (A) = (D))
#define STORE_WORD(A, D)        (*(volatile uint32_t *) (A) = (D))

#define LOAD_BYTE(A)            (*(volatile uint8_t  *) (A))
#define LOAD_HALF(A)            (*(volatile uint16_t *) (A))
#define LOAD_WORD(A)            (*(volatile uint32_t *) (A))

//************************************************************
// System-level controller.
typedef struct {
    volatile uint32_t rst_vec;
    volatile uint32_t sft_irq;
    volatile uint32_t tmr_cfg;
    volatile uint32_t tmr_val;
    volatile uint32_t tmr_valh;
    volatile uint32_t tmr_cmp;
    volatile uint32_t tmr_cmph;
    volatile uint32_t slc_rst;
    volatile uint32_t dev_rst;
    volatile uint32_t sys_icg;
    volatile uint32_t scratch;
    volatile uint32_t gpio_mode;
} slc_type;

#define REG_SLC_BASE            0x08000000UL
#define REG_SLC_RST_VEC         0x08000000UL
#define REG_SLC_SFT_IRQ         0x08000004UL
#define REG_SLC_TMR_CFG         0x08000008UL
#define REG_SLC_TMR_VAL         0x0800000CUL
#define REG_SLC_TMR_VALH        0x08000010UL
#define REG_SLC_TMR_CMP         0x08000014UL
#define REG_SLC_TMR_CMPH        0x08000018UL
#define REG_SLC_SLC_RST         0x0800001CUL
#define REG_SLC_DEV_RST         0x08000020UL
#define REG_SLC_SYS_ICG         0x08000024UL
#define REG_SLC_SCRATCH         0x08000028UL
#define REG_SLC_GPIO_MODE       0x0800002CUL

#define SLC_TMR_CNT_EN_MASK     0x1UL
#define SLC_TMR_CNT_EN_OFFSET   0
#define SLC_TMR_CLR_EN_MASK     0x2UL
#define SLC_TMR_CLR_EN_OFFSET   1
#define SLC_TMR_CLK_DIV_MASK    0xFFFF0000UL
#define SLC_TMR_CLK_DIV_OFFSET  16

//************************************************************
// GPIO.
typedef struct {
    volatile uint32_t pull_up;
    volatile uint32_t pull_down;
    volatile uint32_t in_value;
    volatile uint32_t in_enable;
    volatile uint32_t out_value;
    volatile uint32_t out_enable;
    volatile uint32_t irq_pend;
    volatile uint32_t irq_enable;
} gpio_type;

#define REG_GPIO_BASE           0x70000000UL
#define REG_GPIO_PULL_UP        0x70000000UL
#define REG_GPIO_PULL_DOWN      0x70000004UL
#define REG_GPIO_IN_VALUE       0x70000008UL
#define REG_GPIO_IN_ENABLE      0x7000000CUL
#define REG_GPIO_OUT_VALUE      0x70000010UL
#define REG_GPIO_OUT_ENABLE     0x70000014UL
#define REG_GPIO_IRQ_PEND       0x70000018UL
#define REG_GPIO_IRQ_ENABLE     0x7000001CUL

//************************************************************
// UART.
typedef struct {
    volatile uint32_t glb_cfg;
    volatile uint32_t txq_cap;
    volatile uint32_t txq_len;
    volatile uint32_t txq_clr;
    volatile uint32_t txq_dat;
    volatile uint32_t rxq_cap;
    volatile uint32_t rxq_len;
    volatile uint32_t rxq_clr;
    volatile uint32_t rxq_dat;
    volatile uint32_t ie;
    volatile uint32_t ip;
    volatile uint32_t tx_irq_th;
    volatile uint32_t rx_irq_th;
} uart_type;

#define REG_UART_BASE           0x70001000UL
#define REG_UART_GLB_CFG        0x70001000UL
#define REG_UART_TXQ_CAP        0x70001004UL
#define REG_UART_TXQ_LEN        0x70001008UL
#define REG_UART_TXQ_CLR        0x7000100CUL
#define REG_UART_TXQ_DAT        0x70001010UL
#define REG_UART_RXQ_CAP        0x70001014UL
#define REG_UART_RXQ_LEN        0x70001018UL
#define REG_UART_RXQ_CLR        0x7000101CUL
#define REG_UART_RXQ_DAT        0x70001020UL
#define REG_UART_IE             0x70001024UL
#define REG_UART_IP             0x70001028UL
#define REG_UART_TX_IRQ_TH      0x7000102CUL
#define REG_UART_RX_IRQ_TH      0x70001030UL

#define UART_TX_EN_MASK         0x1UL
#define UART_TX_EN_OFFSET       0
#define UART_RX_EN_MASK         0x2UL
#define UART_RX_EN_OFFSET       1
#define UART_NBITS_MASK         0xCUL
#define UART_NBITS_OFFSET       2
#define UART_NSTOP_MASK         0x10UL
#define UART_NSTOP_OFFSET       4
#define UART_ENDIAN_MASK        0x20UL
#define UART_ENDIAN_OFFSET      5
#define UART_PARITY_EN_MASK     0x80UL
#define UART_PARITY_EN_OFFSET   7
#define UART_PARITY_TYPE_MASK   0x300UL
#define UART_PARITY_TYPE_OFFSET 8
#define UART_CLK_DIV_MASK       0xFFFF0000UL
#define UART_CLK_DIV_OFFSET     16

#define UART_TX_IRQ_MASK        0x1
#define UART_RX_IRQ_MASK        0x2

#define UART_BAUD_RATE_1200     1200
#define UART_BAUD_RATE_2400     2400
#define UART_BAUD_RATE_4800     4800
#define UART_BAUD_RATE_9600     9600
#define UART_BAUD_RATE_19200    19200
#define UART_BAUD_RATE_38400    38400
#define UART_BAUD_RATE_57600    57600
#define UART_BAUD_RATE_115200   115200
#define UART_BAUD_RATE_230400   230400
#define UART_BAUD_RATE_460800   460800
#define UART_BAUD_RATE_921600   921600

#define UART_PARITY_TYPE_SPACE  0
#define UART_PARITY_TYPE_MARK   1
#define UART_PARITY_TYPE_ODD    2
#define UART_PARITY_TYPE_EVEN   3

#define UART_LITTLE_ENDIAN      0
#define UART_BIG_ENDIAN         1

#define UART_MAX_QLEN           8
#define UART_DEFAULT_ENDIAN     UART_LITTLE_ENDIAN
#define UART_DEFAULT_NUM_BITS   8   // 5 ~ 8
#define UART_DEFAULT_NUM_STOPS  1   // 1 or 2

//************************************************************
// I2C.
typedef struct {
    volatile uint32_t glb_cfg;
    volatile uint32_t nframes;
    volatile uint32_t start;
    volatile uint32_t busy;
    volatile uint32_t txq_cap;
    volatile uint32_t txq_len;
    volatile uint32_t txq_clr;
    volatile uint32_t txq_dat;
    volatile uint32_t rxq_cap;
    volatile uint32_t rxq_len;
    volatile uint32_t rxq_clr;
    volatile uint32_t rxq_dat;
    volatile uint32_t ie;
    volatile uint32_t ip;
    volatile uint32_t tx_irq_th;
    volatile uint32_t rx_irq_th;
} i2c_type;

#define REG_I2C_BASE        0x70002000UL
#define REG_I2C_GLB_CFG     0x70002000UL
#define REG_I2C_NFRAMES     0x70002004UL
#define REG_I2C_START       0x70002008UL
#define REG_I2C_BUSY        0x7000200CUL
#define REG_I2C_TXQ_CAP     0x70002010UL
#define REG_I2C_TXQ_LEN     0x70002014UL
#define REG_I2C_TXQ_CLR     0x70002018UL
#define REG_I2C_TXQ_DAT     0x7000201CUL
#define REG_I2C_RXQ_CAP     0x70002020UL
#define REG_I2C_RXQ_LEN     0x70002024UL
#define REG_I2C_RXQ_CLR     0x70002028UL
#define REG_I2C_RXQ_DAT     0x7000202CUL
#define REG_I2C_IE          0x70002030UL
#define REG_I2C_IP          0x70002034UL
#define REG_I2C_TX_IRQ_TH   0x70002038UL
#define REG_I2C_RX_IRQ_TH   0x7000203CUL

#define I2C_SDA_DLY_MASK    0xFFFFUL
#define I2C_SDA_DLY_OFFSET  0
#define I2C_CLK_DIV_MASK    0xFFFF0000UL
#define I2C_CLK_DIV_OFFSET  16

//************************************************************
// SPI.
typedef struct {
    volatile uint32_t glb_cfg;
    volatile uint32_t recv_en;
    volatile uint32_t cs_idle;
    volatile uint32_t cs_mask;
    volatile uint32_t txq_cap;
    volatile uint32_t txq_len;
    volatile uint32_t txq_clr;
    volatile uint32_t txq_dat;
    volatile uint32_t rxq_cap;
    volatile uint32_t rxq_len;
    volatile uint32_t rxq_clr;
    volatile uint32_t rxq_dat;
    volatile uint32_t ie;
    volatile uint32_t ip;
    volatile uint32_t tx_irq_th;
    volatile uint32_t rx_irq_th;
} spi_type;

typedef struct {
    unsigned int cpol : 1;
    unsigned int cpha : 1;
    unsigned int endian : 1;
    unsigned int unit_len : 5;
    unsigned int sck_dly : 8;
    unsigned int clk_div : 16;
} spi_cfg;

#define SPI0_ID             0
#define SPI1_ID             1

#define REG_SPI0_BASE       0x70003000UL
#define REG_SPI0_GLB_CFG    0x70003000UL
#define REG_SPI0_RECV_EN    0x70003004UL
#define REG_SPI0_CS_IDLE    0x70003008UL
#define REG_SPI0_CS_MASK    0x7000300CUL
#define REG_SPI0_TXQ_CAP    0x70003010UL
#define REG_SPI0_TXQ_LEN    0x70003014UL
#define REG_SPI0_TXQ_CLR    0x70003018UL
#define REG_SPI0_TXQ_DAT    0x7000301CUL
#define REG_SPI0_RXQ_CAP    0x70003020UL
#define REG_SPI0_RXQ_LEN    0x70003024UL
#define REG_SPI0_RXQ_CLR    0x70003028UL
#define REG_SPI0_RXQ_DAT    0x7000302CUL
#define REG_SPI0_IE         0x70003030UL
#define REG_SPI0_IP         0x70003034UL
#define REG_SPI0_TX_IRQ_TH  0x70003038UL
#define REG_SPI0_RX_IRQ_TH  0x7000303CUL

#define REG_SPI1_BASE       0x70004000UL
#define REG_SPI1_GLB_CFG    0x70004000UL
#define REG_SPI1_RECV_EN    0x70004004UL
#define REG_SPI1_CS_IDLE    0x70004008UL
#define REG_SPI1_CS_MASK    0x7000400CUL
#define REG_SPI1_TXQ_CAP    0x70004010UL
#define REG_SPI1_TXQ_LEN    0x70004014UL
#define REG_SPI1_TXQ_CLR    0x70004018UL
#define REG_SPI1_TXQ_DAT    0x7000401CUL
#define REG_SPI1_RXQ_CAP    0x70004020UL
#define REG_SPI1_RXQ_LEN    0x70004024UL
#define REG_SPI1_RXQ_CLR    0x70004028UL
#define REG_SPI1_RXQ_DAT    0x7000402CUL
#define REG_SPI1_IE         0x70004030UL
#define REG_SPI1_IP         0x70004034UL
#define REG_SPI1_TX_IRQ_TH  0x70004038UL
#define REG_SPI1_RX_IRQ_TH  0x7000403CUL

#define SPI_CPOL_MASK       0x1
#define SPI_CPOL_OFFSET     0
#define SPI_CPHA_MASK       0x2
#define SPI_CPHA_OFFSET     1
#define SPI_ENDIAN_MASK     0x4
#define SPI_ENDIAN_OFFSET   2
#define SPI_UNIT_LEN_MASK   0xF8
#define SPI_UNIT_LEN_OFFSET 3
#define SPI_SCK_DLY_MASK    0xFF00
#define SPI_SCK_DLY_OFFSET  8
#define SPI_CLK_DIV_MASK    0xFFFF0000
#define SPI_CLK_DIV_OFFSET  16

#define SPI_TX_IRQ_MASK     0x1
#define SPI_RX_IRQ_MASK     0x2

#define SPI_UNIT_LEN_8BITS  7
#define SPI_UNIT_LEN_16BITS 15
#define SPI_UNIT_LEN_32BITS 31

#define SPI_LITTLE_ENDIAN   0
#define SPI_BIG_ENDIAN      1

#define SPI_DEFAULT_CS_IDLE 0xF

//************************************************************
// General timer & watch dog.
typedef struct {
    volatile uint32_t cfg;
    volatile uint32_t val;
    volatile uint32_t cmp;
    volatile uint32_t clr;
} tmr_type;

#define REG_TMR_BASE        0x70005000UL
#define REG_TMR_CFG         0x70005000UL
#define REG_TMR_VAL         0x70005004UL
#define REG_TMR_CMP         0x70005008UL
#define REG_TMR_CLR         0x7000500CUL

#define REG_WDT_BASE        0x70006000UL
#define REG_WDT_CFG         0x70006000UL
#define REG_WDT_VAL         0x70006004UL
#define REG_WDT_CMP         0x70006008UL
#define REG_WDT_CLR         0x7000600CUL

#define TMR_CNT_EN_MASK     0x1UL
#define TMR_CNT_EN_OFFSET   0
#define TMR_CLR_EN_MASK     0x2UL
#define TMR_CLR_EN_OFFSET   1
#define TMR_EVT_EN_MASK     0x4UL
#define TMR_EVT_EN_OFFSET   2
#define TMR_CLK_DIV_MASK    0xFFFF0000UL
#define TMR_CLK_DIV_OFFSET  16

//************************************************************
// Debugger.
typedef struct {
    volatile uint32_t dummy;
} dbg_type;

#define REG_DBG_BASE        0x70007000UL

//************************************************************
// Memories.
#define ROM_START_ADDR      0x04000000UL
#define ROM_BYTE_LENTH      8

#define SRAM_START_ADDR     0x10000000UL
#define SRAM_BYTE_LENGTH    65536

#define EFLASH_START_ADDR   0x20000000UL
#define EFLASH_BYTE_LENGTH  1048576

//************************************************************
// Device declarations.
#define SLC                 ((slc_type  *) REG_SLC_BASE )
#define GPIO                ((gpio_type *) REG_GPIO_BASE)
#define UART                ((uart_type *) REG_UART_BASE)
#define I2C                 ((i2c_type  *) REG_I2C_BASE )
#define SPI0                ((spi_type  *) REG_SPI0_BASE)
#define SPI1                ((spi_type  *) REG_SPI1_BASE)
#define TMR                 ((tmr_type  *) REG_TMR_BASE )
#define WDT                 ((tmr_type  *) REG_WDT_BASE )
#define DBG                 ((dbg_type  *) REG_DBG_BASE )

//************************************************************
// Functions.
void uv_tmr_init(bool auto_clr, uint32_t clk_div, uint64_t cmp);
void uv_tmr_start();
void uv_tmr_stop();
void uv_tmr_set_val(uint64_t val);
uint64_t uv_tmr_get_val();

void uv_sys_tmr_init(bool auto_clr, uint32_t clk_div, uint64_t cmp);
void uv_sys_tmr_start();
void uv_sys_tmr_stop();
void uv_sys_tmr_set_val(uint64_t val);
uint64_t uv_sys_tmr_get_val();

void uv_uart_init(bool tx_en, bool rx_en, uint32_t baud_rate);
void uv_uart_set_parity(bool parity_en, uint32_t parity_type);
void uv_uart_set_tx_irq(bool tx_ie, uint32_t tx_th);
void uv_uart_set_rx_irq(bool rx_ie, uint32_t rx_th);
void uv_uart_send_data(uint8_t *buf, size_t len);
void uv_uart_recv_data(uint8_t *buf, size_t len);

void uv_spi_init(uint32_t idx, uint32_t cs_mask, bool rx_en, spi_cfg *cfg);
void uv_spi_set_tx_irq(uint32_t idx, bool tx_ie, uint32_t tx_th);
void uv_spi_set_rx_irq(uint32_t idx, bool rx_ie, uint32_t rx_th);
void uv_spi_send_bytes(uint32_t idx, uint8_t  *buf, size_t len);
void uv_spi_recv_bytes(uint32_t idx, uint8_t  *buf, size_t len);
void uv_spi_send_halfs(uint32_t idx, uint16_t *buf, size_t len);
void uv_spi_recv_halfs(uint32_t idx, uint16_t *buf, size_t len);
void uv_spi_send_words(uint32_t idx, uint32_t *buf, size_t len);
void uv_spi_recv_words(uint32_t idx, uint32_t *buf, size_t len);

#endif  // __UV_SYS__
