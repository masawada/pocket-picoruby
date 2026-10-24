#include "../include/pocket.h"

#include "font_8x16.h"

void pocket_fb_fill_rect(uint16_t *fb, int x, int y, int w, int h, uint16_t colour)
{
  if (x < 0) { w += x; x = 0; }
  if (y < 0) { h += y; y = 0; }
  if (x + w > POCKET_WIDTH) w = POCKET_WIDTH - x;
  if (y + h > POCKET_HEIGHT) h = POCKET_HEIGHT - y;
  if (w <= 0 || h <= 0) return;

  for (int row = y; row < y + h; row++) {
    uint16_t *p = fb + row * POCKET_WIDTH + x;
    for (int i = 0; i < w; i++) {
      p[i] = colour;
    }
  }
}

static void draw_glyph(uint16_t *fb, int x, int y, unsigned char c, uint16_t fg, int bg)
{
  if (c < FONT_FIRST_CHAR || c > FONT_LAST_CHAR) c = '?';
  const uint8_t *glyph = font_glyphs[c - FONT_FIRST_CHAR];
  for (int gy = 0; gy < FONT_HEIGHT; gy++) {
    int py = y + gy;
    if (py < 0 || py >= POCKET_HEIGHT) continue;
    uint16_t *row = fb + py * POCKET_WIDTH;
    uint8_t bits = glyph[gy];
    for (int gx = 0; gx < FONT_WIDTH; gx++) {
      int px = x + gx;
      if (px < 0 || px >= POCKET_WIDTH) continue;
      if (bits & (0x80 >> gx)) {
        row[px] = fg;
      }
      else if (bg >= 0) {
        row[px] = (uint16_t)bg;
      }
    }
  }
}

void pocket_fb_draw_text(uint16_t *fb, int x, int y, const char *s, size_t len, uint16_t fg, int bg)
{
  for (size_t i = 0; i < len; i++) {
    unsigned char c = (unsigned char)s[i];
    if (c >= 0x80 && c < 0xc0) continue; /* UTF-8 continuation: the lead byte drew '?' */
    draw_glyph(fb, x, y, c, fg, bg);
    x += FONT_WIDTH;
  }
}
