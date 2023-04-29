// See LICENSE for license details.

#include <stdio.h>

void _init()
{
#ifndef NO_INIT
  printf("+++++++++++ INIT +++++++++++\n");
#endif
}

void _fini() {
#ifndef NO_FINI
  printf("----------- FINI -----------\n");
#endif
}
