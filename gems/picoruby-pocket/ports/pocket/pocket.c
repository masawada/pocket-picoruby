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
#include "riscv.h"

void pocket_port_audio_pump(void);

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

/*-------------------------------------
 * Audio: the firmware's 1 ms tick calls pocket_port_audio_pump(), which tops
 * the APF FIFO (4096 stereo samples) up to two frames' worth. Ruby changes
 * the synth state from thread context, so it masks the tick meanwhile.
 *------------------------------------*/

#define AUDIO_TARGET (POCKET_SYNTH_RATE / 60 * 2)
#define AUDIO_CHUNK 64

void pocket_port_audio_lock(void)
{
  csr_clear(mstatus, MSTATUS_MIE);
}

void pocket_port_audio_unlock(void)
{
  csr_set(mstatus, MSTATUS_MIE);
}

void pocket_port_audio_pump(void)
{
  static bool enabled;
  int16_t buf[AUDIO_CHUNK];
  int needed = AUDIO_TARGET - (int)apf_audio_buffer_fill_read();
  while (needed > 0) {
    size_t n = needed < AUDIO_CHUNK ? (size_t)needed : AUDIO_CHUNK;
    pocket_synth_render(buf, n);
    for (size_t i = 0; i < n; i++) {
      uint32_t s = (uint16_t)buf[i];
      apf_audio_out_write(s | (s << 16));
    }
    needed -= (int)n;
  }
  if (!enabled) {
    apf_audio_playback_en_write(1);
    enabled = true;
  }
}
