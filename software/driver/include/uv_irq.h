// See LICENSE for license details.

#ifndef __UV_IRQ__
#define __UV_IRQ__

#include "uv_sys.h"

// General definitions.
#define REG_IRQ_CLAIM       0x08000038
#define REG_TARGET_TH       0x0800003C

#define EXT_IRQ_NUM         64
#define REG_EXT_IP_START    0x08000040
#define REG_EXT_IP_NUM      (EXT_IRQ_NUM / 32 + (EXT_IRQ_NUM % 32 == 0 ? 0 : 1))
#define REG_EXT_IP_END      (REG_EXT_IP_START + (REG_EXT_IP_NUM << 2) - 4)
#define REG_EXT_IE_START    (REG_EXT_IP_START + (REG_EXT_IP_NUM << 2))
#define REG_EXT_IE_NUM      (EXT_IRQ_NUM / 32 + (EXT_IRQ_NUM % 32 == 0 ? 0 : 1))
#define REG_EXT_IE_END      (REG_EXT_IE_START + (REG_EXT_IE_NUM << 2) - 4)
#define REG_EXT_PR_START    (REG_EXT_IE_START + (REG_EXT_IE_NUM << 2))
#define REG_EXT_PR_NUM      (EXT_IRQ_NUM)
#define REG_EXT_PR_END      (REG_EXT_PR_START + (REG_EXT_PR_NUM << 2) - 4)
#define REG_EXT_TG_START    (REG_EXT_PR_START + (REG_EXT_PR_NUM << 2))
#define REG_EXT_TG_NUM      (EXT_IRQ_NUM)
#define REG_EXT_TG_END      (REG_EXT_TG_START + (REG_EXT_TG_NUM << 2) - 4)

#define GET_EXT_IP(i)       (LOAD_WORD(REG_EXT_IP_START + i/8) >> (i%32))
#define GET_EXT_IE(i)       (LOAD_WORD(REG_EXT_IE_START + i/8) >> (i%32))
#define SET_EXT_IE(i)       (STORE_WORD(REG_EXT_IE_START + i/8, GET_EXT_IE(i) |  (1 << (i%32))))
#define CLR_EXT_IE(i)       (STORE_WORD(REG_EXT_IE_START + i/8, GET_EXT_IE(i) & ~(1 << (i%32))))

#define GET_EXT_PR(i)       (LOAD_WORD(REG_EXT_PR_START + (i << 2)))
#define GET_EXT_TG(i)       (LOAD_WORD(REG_EXT_TG_START + (i << 2)))
#define SET_EXT_PR(i, p)    (STORE_WORD(REG_EXT_PR_START + (i << 2), p))
#define SET_EXT_TG(i, t)    (STORE_WORD(REG_EXT_TG_START + (i << 2), t))

#define UART_IRQ            0
#define SPI0_IRQ            1
#define SPI1_IRQ            2
#define I2C_IRQ             3
#define TMR_IRQ             4
#define WDT_IRQ             5
#define GPIO_IRQ(g)         (8 + g)

// Core-level IRQ control.
static inline void uv_enable_glb_irq() {
    set_csr(mstatus, MSTATUS_MIE);
}

static inline void uv_disable_glb_irq() {
    clear_csr(mstatus, MSTATUS_MIE);
}

static inline void uv_enable_tmr_irq() {
    set_csr(mie, MIP_MTIP);
}

static inline void uv_disable_tmr_irq() {
    clear_csr(mie, MIP_MTIP);
}

static inline void uv_enable_sft_irq() {
    set_csr(mie, MIP_MSIP);
}

static inline void uv_disable_sft_irq() {
    clear_csr(mie, MIP_MSIP);
}

static inline void uv_enable_ext_irq() {
    set_csr(mie, MIP_MEIP);
}

static inline void uv_disable_ext_irq() {
    clear_csr(mie, MIP_MEIP);
}

// System-level IRQ control.
static inline void uv_config_ext_irq(uint32_t irq, uint32_t priority, uint32_t trigger) {
    SET_EXT_PR(irq, priority);
    SET_EXT_TG(irq, trigger);
}

static inline void uv_set_target_threshold(uint32_t th) {
    STORE_WORD(REG_TARGET_TH, th);
}

#endif // __UV_IRQ__
