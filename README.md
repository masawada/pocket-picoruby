# pocket-picoruby

[PicoRuby](https://github.com/picoruby/picoruby) running on the Analogue
Pocket, on the RISC-V soft core of [agg23/openfpga-litex](https://github.com/agg23/openfpga-litex).
The Pocket boots a fixed Ruby runtime from the SD card, loads any `.rb` you
pick from the core menu, compiles it on the device and runs it. Tetris is the
demo game, written entirely in Ruby.

```
Cores/masawada.PicoRuby/     core definition + the openfpga-litex bitstream
Assets/picoruby/common/
  boot.bin                   the runtime (PicoRuby + this firmware)
  main.rb                    default script
  tetris.rb                  Tetris
  examples/*.rb              small demos
```

The same scripts run in a browser: `web/` hosts a WebAssembly build of the
runtime with a canvas for the screen and the keyboard as the gamepad, and the
tests run on that build under Node.

## What is in the repository

| Path | Role |
| --- | --- |
| `firmware/` | C firmware for the SoC: boot, on-screen console, 1 ms timer tick, PicoRuby HAL, reading the script from the data slot |
| `gems/picoruby-pocket/` | The `Pocket` module for Ruby: screen (RGB565 framebuffer, 8x16 font), vsync, gamepad, a 4-voice synth. See [docs/pocket-api.md](docs/pocket-api.md) |
| `build_config/` | PicoRuby build configurations for the device (`pocket-picoruby.rb`) and the browser (`pocket-wasm.rb`) |
| `core/` | Analogue core JSON (`core.json`, `data.json`, ...) for the `masawada.PicoRuby` core on platform `picoruby` |
| `ruby/` | Ruby scripts: `main.rb`, `examples/`, Tetris in `lib/tetris/` + `tetris_main.rb` |
| `test/` | picotest suites, run on the wasm build |
| `web/` | Browser runner (`runner.c` host, `runner.js`, `index.html`) |
| `scripts/` | Fetch, build, package, test helpers |
| `vendor/` | Submodules: `picoruby`, `openfpga-litex` (both unmodified) |

[docs/architecture.md](docs/architecture.md) explains how the pieces fit,
the memory map, and what the 57 MHz core can and cannot do.

## Prerequisites

- macOS on Apple silicon (the toolchain fetch script downloads the
  `darwin-arm64` build; other hosts need `scripts/fetch-toolchain.sh` adjusted)
- CRuby 3.4 or newer (`.ruby-version` names 4.0.1) with `rake`
- Node.js 20+ for the browser runner and the tests
- Emscripten (`brew install emscripten`) for the browser runner and the tests
- An Analogue Pocket with openFPGA enabled and an SD card

No FPGA toolchain is needed: the bitstream comes from the openfpga-litex
release and is not modified.

## Build

```sh
git clone --recurse-submodules https://github.com/masawada/pocket-picoruby
cd pocket-picoruby

scripts/fetch-toolchain.sh      # xPack riscv-none-elf-gcc into .toolchain/
scripts/fetch-bitstream.sh      # openfpga-litex 0.1.0 release into .cache/
scripts/build-picoruby.sh       # libmruby.a for rv32imafdc (vendor/picoruby/build/pocket-picoruby)
make -C firmware                # firmware/build/boot.bin
scripts/package.sh              # dist/pocket/ and dist/masawada.PicoRuby.zip
```

`scripts/package.sh` also bundles Tetris into a single file
(`scripts/bundle-rb.rb`) and copies `ruby/main.rb` and `ruby/examples/`.

### Browser runner and tests

```sh
scripts/build-wasm.sh           # web/dist/pocket.js (browser) and pocket-node.js (Node)
scripts/serve-web.sh            # then open http://localhost:8000/web/?script=../build/tetris.rb
node scripts/run-rb.mjs ruby/examples/hello.rb   # run a script headlessly
ruby scripts/test.rb            # picotest suites in test/
```

In the browser, arrows are the d-pad, `Z`/`X` are A/B, `A`/`S` are X/Y,
`Q`/`W` are L/R, Shift is Select and Enter is Start.

## Install on the Pocket

Copy `Cores/`, `Platforms/` and `Assets/` from `dist/pocket/` onto the SD
card root (merge with what is there). The core appears under the
*Development* category as *PicoRuby*.

- On launch the runtime shows a console, then loads and runs
  `Assets/picoruby/common/main.rb`.
- To run another script, open the core menu, go to *Core Settings* →
  *Load Script* and pick any `.rb` on the card. The core resets and runs it.
  The choice is remembered across launches.
- Ruby output (`puts`) and uncaught exceptions appear on the screen; stderr
  and exceptions in red.

### Tetris

Load `tetris.rb`. D-pad moves, down soft-drops, up hard-drops, A/B rotate,
Start restarts after game over. Moves, locks, line clears and game over have
sound effects. Scoring follows the usual guideline
(100/300/500/800 x level, plus drop bonuses); the level rises every 10 lines
and speeds up gravity; a 30-frame lock delay allows last-moment moves.

## Writing scripts

A script is plain Ruby for the PicoRuby (mruby) VM, with the `Pocket` module
for the hardware. The usual loop:

```ruby
D = Pocket::Display
input = Pocket::Input::State.new
x = 0

loop do
  input.update
  x += 1 if input.held?(Pocket::Input::RIGHT)
  D.clear(Pocket.rgb(0, 0, 40))
  D.fill_rect(x, 100, 16, 16, Pocket.rgb(255, 200, 0))
  D.draw_text(8, 8, "frame #{Pocket.frame_count}", 0xffff)
  Pocket.wait_vsync
  D.flush
end
```

Draw, wait for vsync, flush. Keep per-frame work small: the Pocket runs about
3000 Ruby operations per 60 Hz frame, so redraw what changed rather than the
whole screen (see how `ruby/tetris_main.rb` does it). `sleep`, `sleep_ms`,
`Machine.uptime_us`, `rand` and the core class extensions (`String`, `Array`,
`Hash`, `Math`, `Struct`, ...) are available; there is no filesystem and no
`require` for files on the SD card, so a program ships as one file
(`scripts/bundle-rb.rb` concatenates sources).

The full API is in [docs/pocket-api.md](docs/pocket-api.md).

## Acknowledgements

- [agg23/openfpga-litex](https://github.com/agg23/openfpga-litex) for the
  SoC, bitstream and generated headers
- [picoruby/picoruby](https://github.com/picoruby/picoruby) for the VM,
  compiler and build system
- The Shinonome font (public domain) for the 8x16 glyphs

## License

MIT, see [LICENSE](LICENSE). The submodules carry their own licenses.
