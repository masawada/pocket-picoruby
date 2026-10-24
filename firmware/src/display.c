#include "display.h"

static uint16_t *fb;

void display_init(void)
{
  fb = (uint16_t *)(uintptr_t)video_framebuffer_dma_base_read();
}

uint16_t *display_framebuffer(void)
{
  return fb;
}

void display_fill_rect(int x, int y, int w, int h, uint16_t colour)
{
  if (x < 0) { w += x; x = 0; }
  if (y < 0) { h += y; y = 0; }
  if (x + w > DISPLAY_WIDTH) w = DISPLAY_WIDTH - x;
  if (y + h > DISPLAY_HEIGHT) h = DISPLAY_HEIGHT - y;
  if (w <= 0 || h <= 0) return;

  for (int row = y; row < y + h; row++) {
    uint16_t *p = fb + row * DISPLAY_WIDTH + x;
    for (int i = 0; i < w; i++) {
      p[i] = colour;
    }
  }
}

void display_clear(uint16_t colour)
{
  display_fill_rect(0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT, colour);
}

void display_flush(void)
{
  flush_cpu_dcache();
}

void display_wait_vblank(void)
{
  for (;;) {
    uint32_t video = apf_video_video_read();
    if (apf_video_video_vblank_triggered_extract(video)) {
      return;
    }
  }
}
