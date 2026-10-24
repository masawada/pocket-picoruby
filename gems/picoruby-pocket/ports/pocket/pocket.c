/*
 * Device port: the LiteX framebuffer and APF registers. Compiled by
 * firmware/Makefile, not by the gem build.
 */
#include "pocket.h"

#include "display.h"
#include "litex.h"

uint16_t *pocket_port_framebuffer(void)
{
  return display_framebuffer();
}

void pocket_port_flush(void)
{
  display_flush();
}

bool pocket_port_vblank_triggered(void)
{
  return apf_video_video_vblank_triggered_read() != 0;
}

uint32_t pocket_port_frame_count(void)
{
  return apf_video_video_frame_counter_read();
}

uint32_t pocket_port_keys(void)
{
  return apf_input_cont1_key_read();
}
