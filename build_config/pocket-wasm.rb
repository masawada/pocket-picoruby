# PicoRuby for the browser runner in web/: the same gems as the Pocket build,
# compiled with Emscripten. The host loop lives in web/runner.c and is linked
# by scripts/build-wasm.sh.
#
# Run from vendor/picoruby:
#   MRUBY_CONFIG=/abs/path/to/this/file rake

require_relative "pocket_gems"

MRuby::CrossBuild.new("pocket-wasm#{ENV['PICORB_DEBUG'] ? '-debug' : ''}") do |conf|
  conf.toolchain :clang
  # Emscripten's libc is POSIX: the posix ports of every gem are compiled,
  # including gems/picoruby-pocket/ports/posix (the in-memory framebuffer).
  conf.ports :posix

  conf.cc.defines << "PICORB_PLATFORM_POSIX"
  conf.cc.defines << "PICORB_PLATFORM_WASM"
  # Same tick as the Pocket so sleep-based timing behaves alike.
  conf.cc.defines << "MRB_TICK_UNIT=1"
  conf.cc.defines << "MRB_TIMESLICE_TICK_COUNT=10"

  conf.cc.defines << "MRB_32BIT"
  conf.cc.defines << "MRB_INT32"
  conf.cc.defines << "MRB_WORD_BOXING"
  conf.cc.defines << "MRB_UTF8_STRING"

  conf.cc.command = 'emcc'
  conf.linker.command = 'emcc'
  conf.archiver.command = 'emar'

  conf.picoruby(alloc_estalloc: false)

  # pocket_common_gems names gems one by one rather than through the "minimum"
  # gembox: on a POSIX build that gembox also links the picoruby and mrbc
  # executables, which have no place in a browser library.
  pocket_common_gems(conf)
  # Test framework for scripts/test.rb (the device build does without it).
  conf.gem core: "picoruby-picotest"
end
