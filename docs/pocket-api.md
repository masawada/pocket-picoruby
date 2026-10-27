# The `Pocket` module

Provided by `gems/picoruby-pocket`, linked into both the device runtime and
the browser build. Everything here behaves the same on both.

## Screen: `Pocket::Display`

The screen is 266x240 pixels, RGB565. Drawing goes to a framebuffer that is
shown after `flush`; nothing appears until then. On the device the leftmost
column (x = 0) is never displayed, a quirk of the 0.1.0 bitstream explained in
[architecture.md](architecture.md); keep anything that matters at x >= 1.

| Method | Description |
| --- | --- |
| `Display.clear(colour = 0)` | Fill the whole screen |
| `Display.fill_rect(x, y, w, h, colour)` | Filled rectangle, clipped to the screen |
| `Display.draw_text(x, y, str, colour, bg = nil)` | UTF-8 text: ASCII in the 8x16 font, JIS X 0208 characters (kana, kanji, full-width symbols) in the 16x16 Shinonome Gothic font, 16 px wide; anything else draws `?`. With `bg` the glyph background is filled, without it only the glyph pixels are drawn |
| `Display.flush` | Make what was drawn visible (copies the changed rows to the display) |
| `Display::WIDTH`, `Display::HEIGHT` | 266, 240 |
| `Display::FONT_WIDTH`, `Display::FONT_HEIGHT` | 8, 16 |

Colours are RGB565 integers. `Pocket.rgb(r, g, b)` builds one from 8-bit
components; `0xffff` is white, `0` is black.

The Pocket hides the leftmost pixel column; start text at x >= 2.

## Timing

| Method | Description |
| --- | --- |
| `Pocket.wait_vsync` | Return when the next vertical blank begins (60 Hz). Call it after drawing and before `flush` |
| `Pocket.frame_count` | Frames displayed since boot |
| `Machine.uptime_us` | Microseconds since boot (from picoruby-machine) |
| `sleep(seconds)`, `sleep_ms(ms)` | From mruby-task; yield to the scheduler |

## Gamepad: `Pocket::Input`

`Pocket::Input.read` returns controller 1 as a bitmap:

| Bit | Constant | | Bit | Constant |
| --- | --- | --- | --- | --- |
| 0 | `UP` | | 8 | `L1` |
| 1 | `DOWN` | | 9 | `R1` |
| 2 | `LEFT` | | 10 | `L2` |
| 3 | `RIGHT` | | 11 | `R2` |
| 4 | `A` | | 12 | `L3` |
| 5 | `B` | | 13 | `R3` |
| 6 | `X` | | 14 | `SELECT` |
| 7 | `Y` | | 15 | `START` |

`Pocket::Input::State` keeps the previous read so edges are easy:

```ruby
input = Pocket::Input::State.new
loop do
  input.update                        # one read per frame
  input.held?(Pocket::Input::LEFT)    # down right now
  input.pressed?(Pocket::Input::A)    # went down this frame
  input.released?(Pocket::Input::A)   # went up this frame
  input.held / input.previous         # the raw bitmaps
  Pocket.wait_vsync
end
```

## Sound: `Pocket::Audio`

Four PSG-style voices, mixed in C and streamed to the Pocket's 48 kHz stereo
FIFO (mono, both channels). Ruby only starts and stops notes; no per-sample
work happens in Ruby.

| Method | Description |
| --- | --- |
| `Audio.play(voice, freq, ms, volume: 128, wave: :square, slide_to: nil, decay: false)` | Play a note on voice 0..3: frequency in Hz, length in ms, volume 0..255. `wave` is `:square`, `:triangle`, `:saw` or `:noise`. `slide_to` glides the pitch to that frequency over the note; `decay: true` fades the volume to zero over the note |
| `Audio.stop(voice = nil)` | Stop one voice, or all |
| `Audio.active?(voice)` | Whether the voice is still sounding |
| `Audio::VOICES` | 4 |

```ruby
Pocket::Audio.play(0, 880, 60)                                   # blip
Pocket::Audio.play(1, 400, 140, slide_to: 1400, decay: true)      # rising sweep
Pocket::Audio.play(3, 4000, 150, wave: :noise, decay: true)       # hit
```

Starting a note replaces whatever that voice was playing. On the device the
FIFO is refilled from the 1 ms timer interrupt and holds two frames of audio;
in the browser a Web Audio node pulls from the same synth once the page has
seen a key press or click (browsers require a gesture before playing sound).

## Output

`puts`, `print` and `p` write to the on-screen console (white), `$stderr`
and uncaught exceptions in red. The console scrolls; it shares the screen
with `Pocket::Display`, so a graphical program normally clears it first.

## Performance notes

A Ruby operation costs about 4 to 6 microseconds on the Pocket's 57 MHz core,
so a 60 Hz frame affords roughly 3000 of them. Method calls cost about 15
operations each. Patterns that keep Tetris at 60 Hz:

- Draw only what changed; track it in Ruby and `fill_rect` just those cells.
- Avoid allocating in the per-frame path (`map` over cells, temporary objects).
- Prefer `while` loops with indices over `each` with blocks in hot loops.
- `flush` copies only the rows drawn since the last flush; a full-screen
  redraw costs about 6 ms of copying on top of the Ruby work.

`ruby/examples/bench.rb` prints timings for the basic operations.

## Porting

The gem talks to the hardware through the `pocket_port_*` functions declared
in `include/pocket.h`: framebuffer, flush, vblank, frame count, keys, and an
audio lock around synth state changes. The port also decides when to pull
samples with `pocket_synth_render`. `ports/pocket/` implements them on the
LiteX SoC and is compiled by `firmware/Makefile` (the firmware's timer tick
calls `pocket_port_audio_pump`); `ports/posix/` implements them on in-memory
buffers for Emscripten, is compiled by the PicoRuby build, and exports
`pocket_host_*` entry points for the JavaScript host.
