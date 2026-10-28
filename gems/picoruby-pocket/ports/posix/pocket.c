/*
 * Host port (wasm and plain POSIX builds): a framebuffer in memory. The
 * browser runner reports vblank at 60 Hz, blits the framebuffer to a canvas
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

bool pocket_port_wait_vblank(void)
{
  return false;
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

/* Single-threaded host: the audio callback and Ruby never overlap. */
void pocket_port_audio_lock(void) {}
void pocket_port_audio_unlock(void) {}

/* The host's audio callback pulls 16-bit mono samples at 48 kHz. */
HOST_EXPORT void pocket_host_render_audio(int16_t *out, int samples)
{
  pocket_synth_render(out, (size_t)samples);
}
