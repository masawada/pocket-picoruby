/*
 * RGB565 framebuffer owned by the LiteX video DMA.
 */
#ifndef POCKET_DISPLAY_H
#define POCKET_DISPLAY_H

#include <stdint.h>

#include "litex.h"

#define DISPLAY_WIDTH VIDEO_FRAMEBUFFER_HRES
#define DISPLAY_HEIGHT VIDEO_FRAMEBUFFER_VRES

#define RGB565(r, g, b) ((uint16_t)((((r) & 0x1f) << 11) | (((g) & 0x3f) << 5) | ((b) & 0x1f)))

void display_init(void);
uint16_t *display_framebuffer(void);
void display_fill_rect(int x, int y, int w, int h, uint16_t colour);
void display_clear(uint16_t colour);
/* Push cached writes out to SDRAM so the DMA sees them. */
void display_flush(void);
void display_wait_vblank(void);

#endif
