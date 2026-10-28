# Architecture

## The pieces

```
Analogue Pocket (openFPGA)
└─ openfpga-litex bitstream (unmodified, from the 0.1.0 release)
   VexRiscv SMP, rv32imafdc, 57.12 MHz, 4 KB I/D caches, no L2
   64 MB SDRAM, 266x240 RGB565 framebuffer DMA, APF bridge (file I/O), gamepad CSRs
   └─ boot.bin (firmware/ + libmruby.a), loaded by the bitstream to 0x40000000
      ├─ console, CLINT 1 ms tick, PicoRuby HAL           firmware/src/
      ├─ PicoRuby: mruby VM + Prism compiler + gems       vendor/picoruby, build_config/
      ├─ picoruby-pocket: Display / Input / vsync         gems/picoruby-pocket
      └─ the script from data slot 1, compiled at boot    Assets/picoruby/common/*.rb
```

The browser build swaps the bottom layer: `web/runner.c` plays the role of
`firmware/src/main.c`, `gems/picoruby-pocket/ports/posix` draws into memory,
and `web/runner.ts` blits it to a canvas and feeds the keyboard.

## Boot sequence (device)

1. The Pocket loads the core; the bitstream reads data slot 0 (`boot.bin`)
   into SDRAM at `0x40000000` and jumps there (`init_asm.S` from
   openfpga-litex sets the stack, clears `.bss`, calls `main`).
2. `main` brings up the console, programs the CLINT for a 1 ms interrupt
   (`timer.c`, trap handler installed in `mtvec`), and prints a one-line CPU
   benchmark.
3. `bridge.c` asks the APF bridge for the file in slot 1 (the script) and
   DMAs it into a 256 KB buffer.
4. `mrb_open_with_custom_alloc` creates the VM on the Ruby heap; the script
   is compiled with Prism (`mrc_load_string_cxt`) and run as a task with
   `mrb_task_run`. The 1 ms tick drives the mruby-task scheduler
   (`sleep`, `sleep_ms`).
5. Exceptions that escape the script are printed in red with their
   backtrace; the firmware then halts. Picking another script from the core
   menu resets the whole core (data slot parameter bit 6), so there is no
   hot reload to get wrong.

## Memory map

| Range | Use |
| --- | --- |
| `0x40000000` | `boot.bin`: `.text`, `.rodata`, `.data`, `.bss` (script buffer, shadow framebuffer, libc heap strip) |
| `0x40C00000` | Framebuffer DMA window, 8 MB (266 x 240 x 2 bytes in use) |
| `0x41400000` .. `0x43C00000` | Ruby heap (Estalloc), 40 MB |
| `0x43C00000` .. `0x44000000` | C stack, growing down from `0x44000000` |
| `0xF0000000` | CSRs: video, input, bridge, RTC, ... (`generated/csr.h`) |
| `0xF0010000` | CLINT: `mtimecmp` at +0x4000, `mtime` at +0xBFF8, counting system clocks |

Everything above the program is placed from constants in the generated
headers (`VIDEO_FRAMEBUFFER_BASE`, `MAIN_RAM_SIZE`), not hard-coded.

## Core definition

`core/data.json` declares two slots:

| Slot | Name | File | Parameters |
| --- | --- | --- | --- |
| 0 | Runtime | `boot.bin` | `0x49`: user-reloadable, read-only, reset core while loading |
| 1 | Script | `main.rb` (default) | `0x249`: the same plus "persist browsed filename" |

Slot 1 is what *Core Settings → Load Script* edits. `core/video.json`
declares 268x240 like the upstream core because the bitstream really sends
268 pixels per line (declaring 266 garbles the picture). The 0.1.0 release
bitstream fills them as 1 black pixel, framebuffer columns 1..265, then 2
black pixels: column 0 is never shown (`target/pocket/core_top.sv` gates the
colour with a one-cycle-late data enable; upstream fixed this after the
release, in commit c21570d). So the visible area is x = 1..265, off-centre by
one pixel, and the console starts 2 px in, which leaves 2 black pixels on each
side of the text. The browser runner shows all 266 columns.

## Display path

Ruby draws into a shadow framebuffer in SDRAM. `Pocket::Display.flush`
copies the rows touched since the last flush into the DMA window and flushes
the data cache (`flush_cpu_dcache`, the VexRiscv `.word 0x500F`). Drawing
directly into the DMA window tears, because a few Ruby calls take
milliseconds while the beam is scanning. `Pocket.wait_vsync` blocks in C on
the device (polls the vblank CSR); in the browser it yields to the scheduler
1 ms at a time until the host reports a frame, which the runner does at 60 Hz
from `requestAnimationFrame` timestamps on displays that refresh at 60 Hz or
faster (120 Hz laptops included).

## Build system

- `build_config/pocket-picoruby.rb` is a PicoRuby `MRuby::CrossBuild` for
  `-march=rv32imafdc_zicsr -mabi=ilp32d` with the xPack GCC. Defines that fix
  `sizeof(mrb_value)` and the `mrb_state` layout (`MRB_INT32`,
  `MRB_WORD_BOXING`, `MRB_32BIT`, `MRB_UTF8_STRING`, task scheduler, Estalloc)
  are mirrored in `firmware/Makefile`; a mismatch crashes in the first
  `mrb_*` call.
- The config drops `MRB_CONSTRAINED_BASELINE_PROFILE` that picoruby-mruby
  applies to non-POSIX targets: it disables the method cache, which is the
  wrong trade for a machine with 40 MB of heap.
- `build_config/pocket_gems.rb` lists the gems shared by both targets so a
  script that runs on one runs on the other. A CrossBuild compiles no gem
  ports; the firmware compiles `ports/pocket/*.c` itself, the Emscripten
  build uses `conf.ports :posix`.
- libc is newlib-nano from the toolchain with `nosys` stubs; `_sbrk` and
  `_write` are provided in `firmware/src/newlib_stubs.c` (printf goes to the
  screen).

## Performance

Measured on the device (`ruby/examples/bench.rb`, 2026-10-25):

| Operation | Time |
| --- | --- |
| 100k iterations of an empty `while` loop | 1.85 s |
| 10k method calls | 0.79 s |
| 10k two-element array allocations | 1.26 s |
| 1000 `fill_rect` 10x10 | 0.26 s |
| 100 `draw_text` of 8 chars | 0.06 s |
| `flush`, full screen / 40 rows | 6.5 ms / 1.3 ms |

The C side is fine (a 10M-iteration register loop takes 1.23 s, a cache miss
about 11 cycles); the cost is the VM's per-opcode work, about 100+
instructions on a core with 4 KB caches and no L2. Hence the budget of about
3000 Ruby operations per 60 Hz frame and the drawing strategy in
`ruby/tetris_main.rb`: nothing is drawn on frames where nothing moved, a move
repaints up to 16 cells, a lock without a line clear repaints only the cells
the piece and its ghost occupied, and only a line clear repaints the well.

## Testing

`scripts/test.rb` drives picotest from CRuby: each test class in `test/` is
embedded into a generated script together with `ruby/lib/**/*.rb` and
executed on the wasm build through `scripts/run-rb.ts` (Node). Game rules
are tested frame by frame with a scripted input; nothing in the tests touches
a screen.
