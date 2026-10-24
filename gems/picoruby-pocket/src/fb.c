#include "../include/pocket.h"

#include "font_8x16.h"
#include "font_jis16.h"

static int dirty_y0 = POCKET_HEIGHT;
static int dirty_y1 = -1;

static void mark_dirty(int y0, int y1)
{
  if (y0 < 0) y0 = 0;
  if (y1 >= POCKET_HEIGHT) y1 = POCKET_HEIGHT - 1;
  if (y0 < dirty_y0) dirty_y0 = y0;
  if (y1 > dirty_y1) dirty_y1 = y1;
}

bool pocket_fb_dirty_rows(int *y0, int *y1)
{
  if (dirty_y1 < dirty_y0) return false;
  *y0 = dirty_y0;
  *y1 = dirty_y1;
  return true;
}

void pocket_fb_dirty_reset(void)
{
  dirty_y0 = POCKET_HEIGHT;
  dirty_y1 = -1;
}

void pocket_fb_fill_rect(uint16_t *fb, int x, int y, int w, int h, uint16_t colour)
{
  if (x < 0) { w += x; x = 0; }
  if (y < 0) { h += y; y = 0; }
  if (x + w > POCKET_WIDTH) w = POCKET_WIDTH - x;
  if (y + h > POCKET_HEIGHT) h = POCKET_HEIGHT - y;
  if (w <= 0 || h <= 0) return;
  mark_dirty(y, y + h - 1);

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

/* 16x16 glyph, two bytes per row. */
static void draw_wide_glyph(uint16_t *fb, int x, int y, const uint8_t *glyph, uint16_t fg, int bg)
{
  for (int gy = 0; gy < 16; gy++) {
    int py = y + gy;
    if (py < 0 || py >= POCKET_HEIGHT) continue;
    uint16_t *row = fb + py * POCKET_WIDTH;
    uint16_t bits = (uint16_t)((glyph[gy * 2] << 8) | glyph[gy * 2 + 1]);
    for (int gx = 0; gx < 16; gx++) {
      int px = x + gx;
      if (px < 0 || px >= POCKET_WIDTH) continue;
      if (bits & (0x8000 >> gx)) {
        row[px] = fg;
      }
      else if (bg >= 0) {
        row[px] = (uint16_t)bg;
      }
    }
  }
}

/* Index into the JIS X 0208 font for a code point, or -1. */
static int jis16_lookup(uint32_t cp)
{
  if (cp > 0xffff) return -1;
  int lo = 0, hi = FONT_JIS16_COUNT - 1;
  while (lo <= hi) {
    int mid = (lo + hi) / 2;
    uint16_t v = font_jis16_codes[mid];
    if (v == cp) return mid;
    if (v < cp) lo = mid + 1; else hi = mid - 1;
  }
  return -1;
}

/* Decode one UTF-8 sequence; malformed input yields U+FFFD and one byte. */
static uint32_t utf8_decode(const unsigned char *s, size_t len, size_t *used)
{
  unsigned char c = s[0];
  size_t need;
  uint32_t cp;
  if (c < 0x80) { *used = 1; return c; }
  else if ((c & 0xe0) == 0xc0) { need = 1; cp = c & 0x1f; }
  else if ((c & 0xf0) == 0xe0) { need = 2; cp = c & 0x0f; }
  else if ((c & 0xf8) == 0xf0) { need = 3; cp = c & 0x07; }
  else { *used = 1; return 0xfffd; }
  if (len < need + 1) { *used = 1; return 0xfffd; }
  for (size_t i = 1; i <= need; i++) {
    if ((s[i] & 0xc0) != 0x80) { *used = 1; return 0xfffd; }
    cp = (cp << 6) | (s[i] & 0x3f);
  }
  *used = need + 1;
  return cp;
}

/* ASCII is drawn 8 px wide from the 8x16 font, JIS X 0208 characters 16 px
 * wide from the 16x16 font; anything else draws '?'. */
void pocket_fb_draw_text(uint16_t *fb, int x, int y, const char *s, size_t len, uint16_t fg, int bg)
{
  if (len > 0) mark_dirty(y, y + FONT_HEIGHT - 1);
  const unsigned char *p = (const unsigned char *)s;
  size_t i = 0;
  while (i < len) {
    size_t used;
    uint32_t cp = utf8_decode(p + i, len - i, &used);
    i += used;
    if (cp < 0x80) {
      draw_glyph(fb, x, y, (unsigned char)cp, fg, bg);
      x += FONT_WIDTH;
      continue;
    }
    int idx = jis16_lookup(cp);
    if (idx < 0) {
      draw_glyph(fb, x, y, '?', fg, bg);
      x += FONT_WIDTH;
    }
    else {
      draw_wide_glyph(fb, x, y, font_jis16_glyphs[idx], fg, bg);
      x += 16;
    }
  }
}
