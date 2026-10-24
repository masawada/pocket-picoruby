# The `Pocket` module

Provided by `gems/picoruby-pocket`, linked into both the device runtime and
the browser build. Everything here behaves the same on both.

## Screen: `Pocket::Display`

The screen is 266x240 pixels, RGB565. Drawing goes to a framebuffer that is
shown after `flush`; nothing appears until then.

| Method | Description |
| --- | --- |
| `Display.clear(colour = 0)` | Fill the whole screen |
| `Display.fill_rect(x, y, w, h, colour)` | Filled rectangle, clipped to the screen |
| `Display.draw_text(x, y, str, colour, bg = nil)` | Text in the 8x16 font (ASCII; other bytes draw `?`). With `bg` the glyph background is filled, without it only the glyph pixels are drawn |
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

The gem talks to the hardware through six C functions declared in
`include/pocket.h` (`pocket_port_framebuffer`, `pocket_port_flush`,
`pocket_port_vblank_triggered`, `pocket_port_wait_vblank`,
`pocket_port_frame_count`, `pocket_port_keys`). `ports/pocket/` implements
them on the LiteX SoC and is compiled by `firmware/Makefile`;
`ports/posix/` implements them on an in-memory buffer for Emscripten and is
compiled by the PicoRuby build.
