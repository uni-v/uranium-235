// See LICENSE for license details.

#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include "encoding.h"

#define MCAUSE_INT 0x80000000
#define MCAUSE_CAUSE 0x7FFFFFFF

__attribute__((weak)) void handle_ext_irq(){};

__attribute__((weak)) void handle_tmr_irq(){};

__attribute__((weak)) void handle_sft_irq(){};

uintptr_t handle_trap(uintptr_t mcause, uintptr_t epc)
{
  if (mcause & 0x80000000)
  {
    if ((mcause & 0x7FFFFFFF) == IRQ_M_EXT)
    {
      handle_ext_irq();
    }
    else if ((mcause & 0x7FFFFFFF) == IRQ_M_SOFT)
    {
      handle_sft_irq();
    }
    else if ((mcause & 0x7FFFFFFF) == IRQ_M_TIMER)
    {
      handle_tmr_irq();
    }
  }
  else
  {
    write(1, "trap\n", 5);
    _exit(1 + mcause);
  }
  return epc;
}
