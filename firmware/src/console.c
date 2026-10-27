#include "console.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "font_8x16.h"

/* The openfpga-litex 0.1.0 bitstream never shows framebuffer column 0: it
 * outputs a 268 px line as 1 black px, columns 1..265, then 2 black px
 * (target/pocket/core_top.sv, fixed upstream after the release). Starting the
 * text grid 2 px in centres it: 33 columns of 8 px leave 2 px on each side. */
#define LEFT_MARGIN 2
#define COLS ((DISPLAY_WIDTH - LEFT_MARGIN) / FONT_WIDTH)
#define ROWS (DISPLAY_HEIGHT / FONT_HEIGHT)

static int cur_x, cur_y;
static uint16_t fg_colour, bg_colour;

static void draw_glyph(int col, int row, unsigned char c)
{
  const uint8_t *glyph = font_glyphs[(c < FONT_FIRST_CHAR || c > FONT_LAST_CHAR ? '?' : c) - FONT_FIRST_CHAR];
  uint16_t *p = display_framebuffer() + row * FONT_HEIGHT * DISPLAY_WIDTH + LEFT_MARGIN + col * FONT_WIDTH;
  for (int y = 0; y < FONT_HEIGHT; y++, p += DISPLAY_WIDTH) {
    uint8_t bits = glyph[y];
    for (int x = 0; x < FONT_WIDTH; x++) {
      p[x] = (bits & (0x80 >> x)) ? fg_colour : bg_colour;
    }
  }
}

static void scroll(void)
{
  uint16_t *fb = display_framebuffer();
  size_t line = (size_t)FONT_HEIGHT * DISPLAY_WIDTH;
  memmove(fb, fb + line, (ROWS - 1) * line * sizeof(uint16_t));
  display_fill_rect(0, (ROWS - 1) * FONT_HEIGHT, DISPLAY_WIDTH, DISPLAY_HEIGHT - (ROWS - 1) * FONT_HEIGHT, bg_colour);
}

static void newline(void)
{
  cur_x = 0;
  if (++cur_y >= ROWS) {
    scroll();
    cur_y = ROWS - 1;
  }
}

static void putc_raw(unsigned char c)
{
  switch (c) {
  case '\n':
    newline();
    return;
  case '\r':
    cur_x = 0;
    return;
  case '\t':
    do {
      putc_raw(' ');
    } while (cur_x % 4 != 0);
    return;
  case '\b':
    if (cur_x > 0) cur_x--;
    return;
  default:
    break;
  }
  if (c < 0x20) return;
  if (c >= 0x80 && c < 0xc0) return; /* UTF-8 continuation byte: the lead byte drew '?' */
  if (cur_x >= COLS) newline();
  draw_glyph(cur_x++, cur_y, c);
}

void console_init(void)
{
  cur_x = cur_y = 0;
  fg_colour = CONSOLE_WHITE;
  bg_colour = CONSOLE_BLACK;
  display_clear(bg_colour);
  display_flush();
}

void console_set_colour(uint16_t fg, uint16_t bg)
{
  fg_colour = fg;
  bg_colour = bg;
}

void console_write(const char *buf, size_t len)
{
  for (size_t i = 0; i < len; i++) {
    putc_raw((unsigned char)buf[i]);
  }
  display_flush();
}

void console_puts(const char *s)
{
  console_write(s, strlen(s));
}

void console_printf(const char *fmt, ...)
{
  char buf[256];
  va_list ap;
  va_start(ap, fmt);
  int n = vsnprintf(buf, sizeof(buf), fmt, ap);
  va_end(ap);
  if (n < 0) return;
  console_write(buf, (size_t)n < sizeof(buf) ? (size_t)n : sizeof(buf) - 1);
}
