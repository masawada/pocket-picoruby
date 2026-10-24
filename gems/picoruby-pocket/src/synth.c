/*
 * PSG-style synth: POCKET_SYNTH_VOICES voices, integer math only (it runs in
 * an interrupt on the device). Each voice is a 32-bit phase accumulator; the
 * wave shape is derived from the phase, the volume from a per-sample step.
 */
#include "../include/pocket.h"

typedef struct {
  bool active;
  pocket_wave_t wave;
  uint32_t phase;
  uint32_t step;        /* phase increment per sample */
  int32_t step_delta;   /* per-sample change of step (pitch slide), 16.16 fixed */
  int32_t step_frac;    /* fractional accumulator for step_delta */
  int32_t volume;       /* 16.16 fixed, 0..255<<16 */
  int32_t volume_delta; /* per-sample change of volume (decay) */
  uint32_t remaining;   /* samples left */
  uint32_t lfsr;        /* noise state */
} voice_t;

static voice_t voices[POCKET_SYNTH_VOICES];

static uint32_t hz_to_step(int hz)
{
  if (hz <= 0) return 0;
  /* 2^32 * hz / rate, computed in 64 bits */
  return (uint32_t)(((uint64_t)hz << 32) / POCKET_SYNTH_RATE);
}

bool pocket_synth_play(int voice, int freq_hz, int slide_to_hz, int ms, int volume, int wave, bool decay)
{
  if (voice < 0 || voice >= POCKET_SYNTH_VOICES) return false;
  if (wave < POCKET_WAVE_SQUARE || wave > POCKET_WAVE_NOISE) return false;
  if (ms <= 0 || volume <= 0 || freq_hz <= 0) {
    pocket_synth_stop(voice);
    return true;
  }
  if (volume > 255) volume = 255;

  voice_t v;
  v.active = true;
  v.wave = (pocket_wave_t)wave;
  v.phase = 0;
  v.step = hz_to_step(freq_hz);
  v.remaining = (uint32_t)ms * (POCKET_SYNTH_RATE / 1000);
  v.step_frac = 0;
  if (slide_to_hz > 0) {
    int64_t diff = (int64_t)hz_to_step(slide_to_hz) - (int64_t)v.step;
    v.step_delta = (int32_t)((diff << 16) / (int64_t)v.remaining);
  }
  else {
    v.step_delta = 0;
  }
  v.volume = volume << 16;
  v.volume_delta = decay ? -(int32_t)(v.volume / (int32_t)v.remaining) : 0;
  v.lfsr = 0xACE1u;

  pocket_port_audio_lock();
  voices[voice] = v;
  pocket_port_audio_unlock();
  return true;
}

void pocket_synth_stop(int voice)
{
  pocket_port_audio_lock();
  if (voice < 0) {
    for (int i = 0; i < POCKET_SYNTH_VOICES; i++) voices[i].active = false;
  }
  else if (voice < POCKET_SYNTH_VOICES) {
    voices[voice].active = false;
  }
  pocket_port_audio_unlock();
}

bool pocket_synth_active(int voice)
{
  if (voice < 0 || voice >= POCKET_SYNTH_VOICES) return false;
  return voices[voice].active;
}

/* One sample of a voice in -32767..32767 before volume. */
static int32_t voice_sample(voice_t *v)
{
  uint32_t p = v->phase;
  switch (v->wave) {
  case POCKET_WAVE_SQUARE:
    return (p & 0x80000000u) ? 32767 : -32767;
  case POCKET_WAVE_TRIANGLE: {
    /* 0..2^32 -> rise to +max at half, fall back */
    int32_t t = (int32_t)(p >> 15);          /* 0..131071 */
    if (t >= 65536) t = 131071 - t;           /* 0..65535..0 */
    return t - 32768;
  }
  case POCKET_WAVE_SAW:
    return (int32_t)(p >> 16) - 32768;
  case POCKET_WAVE_NOISE:
  default:
    /* New random level each time the phase wraps. */
    return (v->lfsr & 1) ? 32767 : -32767;
  }
}

void pocket_synth_render(int16_t *out, size_t samples)
{
  for (size_t n = 0; n < samples; n++) {
    int32_t mix = 0;
    for (int i = 0; i < POCKET_SYNTH_VOICES; i++) {
      voice_t *v = &voices[i];
      if (!v->active) continue;
      int32_t s = voice_sample(v);
      /* volume 0..255 scales to a quarter of full scale per voice */
      mix += (s * (v->volume >> 16)) >> 10;

      uint32_t old_phase = v->phase;
      v->phase += v->step;
      if (v->wave == POCKET_WAVE_NOISE && v->phase < old_phase) {
        uint32_t bit = ((v->lfsr >> 0) ^ (v->lfsr >> 2) ^ (v->lfsr >> 3) ^ (v->lfsr >> 5)) & 1u;
        v->lfsr = (v->lfsr >> 1) | (bit << 15);
      }
      if (v->step_delta) {
        v->step_frac += v->step_delta;
        v->step += (uint32_t)(v->step_frac >> 16);
        v->step_frac &= 0xffff;
      }
      v->volume += v->volume_delta;
      if (v->volume < 0) v->volume = 0;
      if (--v->remaining == 0) v->active = false;
    }
    if (mix > 32767) mix = 32767;
    if (mix < -32767) mix = -32767;
    out[n] = (int16_t)mix;
  }
}
