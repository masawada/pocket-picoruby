# picoruby-pocket

The Analogue Pocket's screen and gamepad for PicoRuby: `Pocket::Display`
(RGB565 framebuffer, rectangles, 8x16 text), `Pocket.wait_vsync`,
`Pocket::Input`. See [docs/pocket-api.md](../../docs/pocket-api.md) for the
Ruby API.

```
include/pocket.h      renderer API and the port contract
src/fb.c              rectangles, text, dirty-row tracking (platform independent)
src/mruby/pocket.c    Ruby bindings
mrblib/pocket.rb      Pocket.rgb, Pocket.wait_vsync, Input constants and Input::State
ports/pocket/         LiteX SoC: shadow framebuffer copied to the DMA window on flush
ports/posix/          in-memory framebuffer for the browser (Emscripten); the host
                      calls pocket_host_vblank / pocket_host_set_keys
tools/bdf2c.rb        converts the Shinonome 8x16 BDF into font_8x16.h at build time
```

Add it to a PicoRuby build with `conf.gem gemdir: "path/to/picoruby-pocket"`
(see `build_config/pocket_gems.rb`). A CrossBuild compiles no ports, so the
firmware compiles `ports/pocket/pocket.c`; a POSIX build (`conf.ports :posix`)
compiles `ports/posix/pocket.c`.
