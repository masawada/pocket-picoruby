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

/* Rows touched since the last reset, so a port that copies the framebuffer
 * out can copy only what changed. Returns false when nothing was drawn. */
bool pocket_fb_dirty_rows(int *y0, int *y1);
void pocket_fb_dirty_reset(void);

/*
 * Synth (src/synth.c): a few PSG-style voices mixed to 16-bit mono at 48 kHz.
 * The port pulls samples whenever its output FIFO needs them.
 */
#define POCKET_SYNTH_RATE 48000
#define POCKET_SYNTH_VOICES 4

typedef enum {
  POCKET_WAVE_SQUARE = 0,
  POCKET_WAVE_TRIANGLE,
  POCKET_WAVE_SAW,
  POCKET_WAVE_NOISE,
} pocket_wave_t;

/* Start a note: frequency in Hz (slides to slide_to_hz over the duration when
 * slide_to_hz > 0), length in ms, volume 0..255, decay fades the volume to 0
 * over the duration. Returns false for a bad voice or wave. */
bool pocket_synth_play(int voice, int freq_hz, int slide_to_hz, int ms, int volume, int wave, bool decay);
void pocket_synth_stop(int voice); /* voice < 0 stops all */
bool pocket_synth_active(int voice);
void pocket_synth_render(int16_t *out, size_t samples);

/* Port contract. */
uint16_t *pocket_port_framebuffer(void);
void pocket_port_flush(void);
/* True once per frame after vblank started; reading clears it. */
bool pocket_port_vblank_triggered(void);
/* Block until the next vblank and return true, or return false at once when
 * the port cannot block (the browser), in which case the caller polls. */
bool pocket_port_wait_vblank(void);
uint32_t pocket_port_frame_count(void);
/* Controller 1 bitmap: bit 0 up, 1 down, 2 left, 3 right, 4 A, 5 B, 6 X, 7 Y,
 * 8 L1, 9 R1, 10 L2, 11 R2, 12 L3, 13 R3, 14 select, 15 start. */
uint32_t pocket_port_keys(void);
/* The synth state is changed by Ruby and read by whatever pulls samples (an
 * interrupt on the device); the port brackets the change with these. */
void pocket_port_audio_lock(void);
void pocket_port_audio_unlock(void);

#endif
