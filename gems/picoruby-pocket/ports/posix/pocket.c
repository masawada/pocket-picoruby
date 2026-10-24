/*
 * Host port (wasm and plain POSIX builds): a framebuffer in memory. The
 * browser runner blits it to a canvas every animation frame, reports vblank
 * and feeds the button bitmap through the pocket_host_* entry points.
 */
#include "../../include/pocket.h"

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#define HOST_EXPORT EMSCRIPTEN_KEEPALIVE
#else
#define HOST_EXPORT
#endif

static uint16_t framebuffer[POCKET_WIDTH * POCKET_HEIGHT];
static bool vblank_triggered;
static uint32_t frame_count;
static uint32_t keys;

uint16_t *pocket_port_framebuffer(void)
{
  return framebuffer;
}

void pocket_port_flush(void)
{
}

bool pocket_port_vblank_triggered(void)
{
  bool v = vblank_triggered;
  vblank_triggered = false;
  return v;
}

uint32_t pocket_port_frame_count(void)
{
  return frame_count;
}

uint32_t pocket_port_keys(void)
{
  return keys;
}

/* Called by the host once per frame. */
HOST_EXPORT void pocket_host_vblank(void)
{
  vblank_triggered = true;
  frame_count++;
}

HOST_EXPORT void pocket_host_set_keys(uint32_t bitmap)
{
  keys = bitmap;
}

HOST_EXPORT uint16_t *pocket_host_framebuffer(void)
{
  return framebuffer;
}
