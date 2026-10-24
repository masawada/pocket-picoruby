/*
 * picoruby-pocket: the Pocket's screen and gamepad for Ruby.
 *
 * The gem draws into a linear RGB565 framebuffer that a port provides
 * (ports/pocket: the LiteX video DMA window; ports/posix: a buffer in memory
 * that the browser runner blits to a canvas).
 */
#ifndef PICORUBY_POCKET_H
#define PICORUBY_POCKET_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define POCKET_WIDTH 266
#define POCKET_HEIGHT 240
#define POCKET_FONT_WIDTH 8
#define POCKET_FONT_HEIGHT 16

/* Renderer (src/fb.c); coordinates are clipped to the screen. */
void pocket_fb_fill_rect(uint16_t *fb, int x, int y, int w, int h, uint16_t colour);
/* bg < 0 leaves the glyph background untouched. */
void pocket_fb_draw_text(uint16_t *fb, int x, int y, const char *s, size_t len, uint16_t fg, int bg);

/* Port contract. */
uint16_t *pocket_port_framebuffer(void);
void pocket_port_flush(void);
/* True once per frame after vblank started; reading clears it. */
bool pocket_port_vblank_triggered(void);
uint32_t pocket_port_frame_count(void);
/* Controller 1 bitmap: bit 0 up, 1 down, 2 left, 3 right, 4 A, 5 B, 6 X, 7 Y,
 * 8 L1, 9 R1, 10 L2, 11 R2, 12 L3, 13 R3, 14 select, 15 start. */
uint32_t pocket_port_keys(void);

#endif
