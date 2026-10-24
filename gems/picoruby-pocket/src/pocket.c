#include "../include/pocket.h"

#if defined(PICORB_VM_MRUBY)

#include "mruby/pocket.c"

#else

#error "picoruby-pocket supports the mruby VM only"

#endif
