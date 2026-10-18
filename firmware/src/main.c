/*
 * M1: smallest possible program for the openfpga-litex SoC.
 * Fills the framebuffer every frame; the colour changes while A is held.
 * Proves the toolchain, the linker layout, vblank polling and input reads.
 */
#include <stdint.h>

#include <generated/csr.h>
#include <generated/soc.h>

#define FB_WIDTH  MAX_DISPLAY_WIDTH
#define FB_HEIGHT MAX_DISPLAY_HEIGHT

#define RGB565(r, g, b) ((uint16_t)((((r) & 0x1f) << 11) | (((g) & 0x3f) << 5) | ((b) & 0x1f)))

#define KEY_FACE_A (1u << 4)

static void fill(uint16_t *fb, uint16_t colour)
{
  for (uint32_t i = 0; i < (uint32_t)FB_WIDTH * FB_HEIGHT; i++) {
    fb[i] = colour;
  }
  flush_cpu_dcache();
}

static void wait_vblank(void)
{
  for (;;) {
    uint32_t video = apf_video_video_read();
    if (apf_video_video_vblank_triggered_extract(video)) {
      return;
    }
  }
}

int main(void)
{
  uint16_t *fb = (uint16_t *)(uintptr_t)video_framebuffer_dma_base_read();

  for (;;) {
    wait_vblank();
    uint32_t keys = apf_input_cont1_key_read();
    fill(fb, (keys & KEY_FACE_A) ? RGB565(31, 0, 0) : RGB565(0, 63, 0));
  }

  return 0;
}
