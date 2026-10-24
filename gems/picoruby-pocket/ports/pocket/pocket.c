/*
 * Device port: the LiteX framebuffer and APF registers. Compiled by
 * firmware/Makefile, not by the gem build.
 *
 * Ruby draws into a shadow buffer; flush copies it to the buffer the video
 * DMA scans out. Drawing straight into the DMA buffer tears: a few Ruby
 * calls take milliseconds, and the beam shows the half-drawn frame. The copy
 * is done right after vblank (see Pocket.wait_vsync) and runs far ahead of
 * the beam, so the screen only ever shows complete frames.
 */
#include <stdint.h>

#include "pocket.h"

#include "display.h"
#include "litex.h"

static uint16_t shadow[POCKET_WIDTH * POCKET_HEIGHT] __attribute__((aligned(8)));

uint16_t *pocket_port_framebuffer(void)
{
  return shadow;
}

/* Copies only the rows drawn since the last flush: a full frame costs ~5 ms
 * on this SoC, while a typical frame touches a few dozen rows. */
void pocket_port_flush(void)
{
  int y0, y1;
  if (!pocket_fb_dirty_rows(&y0, &y1)) return;
  pocket_fb_dirty_reset();

  uint32_t first = (uint32_t)y0 * POCKET_WIDTH / 2;
  uint32_t last = ((uint32_t)y1 + 1) * POCKET_WIDTH / 2; /* rows are 133 words each */
  const uint32_t *src = (const uint32_t *)shadow;
  uint32_t *dst = (uint32_t *)display_framebuffer();
  uint32_t i = first;
  while (i + 4 <= last) {
    dst[i] = src[i];
    dst[i + 1] = src[i + 1];
    dst[i + 2] = src[i + 2];
    dst[i + 3] = src[i + 3];
    i += 4;
  }
  while (i < last) {
    dst[i] = src[i];
    i++;
  }
  display_flush();
}

bool pocket_port_vblank_triggered(void)
{
  return apf_video_video_vblank_triggered_read() != 0;
}

bool pocket_port_wait_vblank(void)
{
  while (apf_video_video_vblank_triggered_read() == 0) {
  }
  return true;
}

uint32_t pocket_port_frame_count(void)
{
  return apf_video_video_frame_counter_read();
}

uint32_t pocket_port_keys(void)
{
  return apf_input_cont1_key_read();
}
