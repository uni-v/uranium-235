// See LICENSE for license details.

#include <unistd.h>

off_t _lseek(int fd, off_t ptr, int dir)
{
  if (isatty(fd))
    return 0;

  return -1;
}
