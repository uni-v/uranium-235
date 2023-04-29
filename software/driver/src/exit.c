// See LICENSE for license details.

#include <unistd.h>
#include "uv_sys.h"

void write_hex(int fd, unsigned long int hex);

void _exit(int code)
{
  const char message[] = "\nProgram exited: ";

  write(STDERR_FILENO, message, sizeof(message) - 1);
  write_hex(STDERR_FILENO, code);
  write(STDERR_FILENO, "\n", 1);
  STORE_WORD(REG_SLC_SCRATCH, 0xcafe0235);

  for (;;);
}
