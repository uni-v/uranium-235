// See LICENSE for license details.

#ifndef __UV_CORE__
#define __UV_CORE__

#include "encoding.h"

#define CORE_COUNTER_START  write_csr(0x320,0)
#define CORE_COUNTER_STOP   write_csr(0x320,~0UL)

#endif // __UV_CORE__