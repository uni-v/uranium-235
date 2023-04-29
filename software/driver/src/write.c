// See LICENSE for license details.

#include <stdint.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include "uv_sys.h"

ssize_t _write(int fd, const void* ptr, size_t len) {
  const char * str = (const char *) ptr;

  if (isatty(fd)) {
    for (size_t i = 0; i < len; i++) {
      STORE_BYTE(REG_SLC_SCRATCH, str[i]);
    }
    return len;
  }

  return -1;
}
