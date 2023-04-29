// See LICENSE for license details.

#include <stdio.h>
#include "uv_sys.h"
#include "uv_irq.h"

#define LOOP_CYC 10000
#define LOOP_NUM 10

static volatile bool tmr_irq_trig = false;

int main() {
    bool auto_clr = true;
    uint32_t clk_div = 0;
    uint64_t tmr_cmp = LOOP_CYC;

    // Configuration.
    uv_enable_glb_irq();
    uv_enable_tmr_irq();
    uv_tmr_init(auto_clr, clk_div, tmr_cmp);

    // Start test.
    printf("Timer started with auto clearing.\n");
    uv_tmr_start();
    for (int i = 0; i < LOOP_NUM; ++i) {
        tmr_irq_trig = false;
        while (!tmr_irq_trig)
            ;
        printf("> Loop %d...\n", i);
    }
    uv_tmr_stop();
    
    uint64_t tmr_val = uv_tmr_get_val();
    printf("Timer stopped at %d.\n", (uint32_t) tmr_val);

    return 0;
}

void handle_tmr_irq() {
    tmr_irq_trig = true; 
}
