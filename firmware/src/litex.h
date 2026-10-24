/*
 * One include for the generated LiteX headers of the openfpga-litex SoC.
 */
#ifndef POCKET_LITEX_H
#define POCKET_LITEX_H

#include <generated/csr.h>
#include <generated/soc.h>
/* soc.h and mem.h both define this, in decimal and in hex; keep mem.h's. */
#undef VIDEO_FRAMEBUFFER_BASE
#include <generated/mem.h>

#endif
