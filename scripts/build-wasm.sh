#!/bin/sh
# Build the browser runner: libmruby.a with Emscripten (vendor/picoruby rake,
# build_config/pocket-wasm.rb) and web/runner.c linked into web/dist/pocket.js.
# Needs emcc (brew install emscripten) and CRuby 3.4+ (see .ruby-version).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PICORUBY="${ROOT}/vendor/picoruby"
BUILD="${PICORUBY}/build/pocket-wasm"
OUT="${ROOT}/web/dist"

command -v emcc >/dev/null || { echo "emcc not found: brew install emscripten" >&2; exit 1; }
# Emscripten compiles its system libraries into a cache on first use; keep that
# out of the (read-only) Homebrew tree.
export EM_CACHE="${EM_CACHE:-${ROOT}/.cache/emscripten}"
mkdir -p "${EM_CACHE}"

(cd "${PICORUBY}" && MRUBY_CONFIG="${ROOT}/build_config/pocket-wasm.rb" rake)

# Must match build_config/pocket-wasm.rb plus what conf.picoruby / picoruby-mruby
# add for a posix build (MRB_BASELINE_PROFILE).
DEFINES="-DPICORB_PLATFORM_POSIX -DPICORB_PLATFORM_WASM -DPICORB_VM_MRUBY -DMRB_USE_TASK_SCHEDULER \
  -DMRB_32BIT -DMRB_INT32 -DMRB_WORD_BOXING -DMRB_UTF8_STRING -DMRB_BASELINE_PROFILE=1 \
  -DMRB_TICK_UNIT=1 -DMRB_TIMESLICE_TICK_COUNT=10"
INCLUDES="-I${PICORUBY}/include \
  -I${PICORUBY}/mrbgems/mruby-compiler/include \
  -I${PICORUBY}/mrbgems/mruby-compiler/lib/prism/include \
  -I${PICORUBY}/build/prism/include \
  -I${PICORUBY}/mrbgems/picoruby-mruby/lib/mruby/include \
  -I${PICORUBY}/mrbgems/picoruby-machine/include \
  -I${PICORUBY}/mrbgems/picoruby-mruby/include \
  -I${PICORUBY}/mrbgems/picoruby-mruby/lib/mruby/mrbgems/mruby-task/include \
  -I${BUILD}/include"

mkdir -p "${OUT}"
# Two links of the same objects: pocket.js for the browser, pocket-node.js for
# scripts/run-rb.mjs (headless runs and tests).
link() {
  emcc -O2 ${DEFINES} ${INCLUDES} \
    -s WASM=1 -s EXPORT_ES6=1 -s MODULARIZE=1 -s ENVIRONMENT="$1" \
    -s INITIAL_MEMORY=64MB -s ALLOW_MEMORY_GROWTH=1 -s STACK_SIZE=2MB \
    -s EXPORTED_RUNTIME_METHODS='["ccall","HEAPU8"]' \
    -s EXPORTED_FUNCTIONS='["_pocket_wasm_init","_pocket_wasm_load","_pocket_wasm_tick","_pocket_wasm_step","_pocket_wasm_alive","_pocket_host_vblank","_pocket_host_set_keys","_pocket_host_framebuffer","_malloc","_free"]' \
    --no-entry \
    "${ROOT}/web/runner.c" "${BUILD}/lib/libmruby.a" \
    -o "${OUT}/$2"
  echo "wrote ${OUT}/$2"
}
link web pocket.js
link node pocket-node.js
