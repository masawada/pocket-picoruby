/*
 * Scrolling text console drawn on the framebuffer with an 8x16 font.
 * This is where Ruby's stdout/stderr and firmware diagnostics end up.
 */
#ifndef POCKET_CONSOLE_H
#define POCKET_CONSOLE_H

#include <stddef.h>
#include <stdint.h>

#include "display.h"

#define CONSOLE_BLACK RGB565(0, 0, 0)
#define CONSOLE_WHITE RGB565(31, 63, 31)
#define CONSOLE_GREY RGB565(16, 32, 16)
#define CONSOLE_RED RGB565(31, 16, 16)
#define CONSOLE_GREEN RGB565(16, 63, 16)

void console_init(void);
void console_set_colour(uint16_t fg, uint16_t bg);
void console_write(const char *buf, size_t len);
void console_puts(const char *s);
void console_printf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

#endif
