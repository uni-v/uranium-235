// See LICENSE for license details.

#include <errno.h>
#include <unistd.h>
#include <sys/stat.h>

int _fstat(int fd, struct stat* st)
{
  if (isatty(fd)) {
    st->st_mode = S_IFCHR;
    return 0;
  }

  return -1;
}
