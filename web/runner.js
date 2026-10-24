// Browser runner: canvas as the Pocket's screen, keyboard as the gamepad.
// Loads dist/pocket.js (built by scripts/build-wasm.sh).

import createModule from "./dist/pocket.js";

const WIDTH = 266;
const HEIGHT = 240;
const MRB_TICK_UNIT = 1;      // must match build_config/pocket-wasm.rb
const BATCH_DURATION = 12;    // ms of VM time per host-loop pass
const MAX_CATCHUP_TICKS = 20;

const KEYMAP = {
  ArrowUp: 1 << 0, ArrowDown: 1 << 1, ArrowLeft: 1 << 2, ArrowRight: 1 << 3,
  KeyZ: 1 << 4,  // A
  KeyX: 1 << 5,  // B
  KeyA: 1 << 6,  // X
  KeyS: 1 << 7,  // Y
  KeyQ: 1 << 8,  // L1
  KeyW: 1 << 9,  // R1
  ShiftLeft: 1 << 14, ShiftRight: 1 << 14, // select
  Enter: 1 << 15, // start
};

const canvas = document.getElementById("screen");
const ctx = canvas.getContext("2d");
const image = ctx.createImageData(WIDTH, HEIGHT);
const log = document.getElementById("log");
const status = document.getElementById("status");

function appendLog(text, cls) {
  const line = document.createElement("div");
  line.textContent = text;
  if (cls) line.className = cls;
  log.appendChild(line);
  log.scrollTop = log.scrollHeight;
}

const Module = await createModule({
  print: (t) => appendLog(t),
  printErr: (t) => appendLog(t, "err"),
});

let keys = 0;
window.addEventListener("keydown", (e) => {
  const bit = KEYMAP[e.code];
  if (bit) { keys |= bit; Module._pocket_host_set_keys(keys); e.preventDefault(); }
});
window.addEventListener("keyup", (e) => {
  const bit = KEYMAP[e.code];
  if (bit) { keys &= ~bit; Module._pocket_host_set_keys(keys); e.preventDefault(); }
});

function blit() {
  const ptr = Module._pocket_host_framebuffer();
  const fb = new Uint16Array(Module.HEAPU8.buffer, ptr, WIDTH * HEIGHT);
  const out = image.data;
  for (let i = 0, o = 0; i < fb.length; i++, o += 4) {
    const p = fb[i];
    out[o] = ((p >> 11) & 0x1f) * 255 / 31;
    out[o + 1] = ((p >> 5) & 0x3f) * 255 / 63;
    out[o + 2] = (p & 0x1f) * 255 / 31;
    out[o + 3] = 255;
  }
  ctx.putImageData(image, 0, 0);
}

function frame() {
  Module._pocket_host_vblank();
  blit();
  requestAnimationFrame(frame);
}

let lastTick = performance.now();
function hostLoop() {
  const now = performance.now();
  let n = 0;
  while (now - lastTick >= MRB_TICK_UNIT && n < MAX_CATCHUP_TICKS) {
    Module._pocket_wasm_tick();
    lastTick += MRB_TICK_UNIT;
    n++;
  }
  if (now - lastTick >= MRB_TICK_UNIT) lastTick = now;

  const start = performance.now();
  let progressed = false;
  while (performance.now() - start < BATCH_DURATION) {
    const s = Module._pocket_wasm_step();
    if (s <= 0) break;
    progressed = true;
  }
  setTimeout(hostLoop, progressed ? 0 : 1);
}

async function run(code, filename) {
  log.textContent = "";
  status.textContent = `running ${filename}`;
  // A fresh VM per script: the simplest way to match "reset core" on the device.
  if (Module.started) {
    window.location.reload();
    return;
  }
  Module.started = true;
  if (Module.ccall("pocket_wasm_init", "number", [], []) !== 0) return;
  const ok = Module.ccall("pocket_wasm_load", "number", ["string", "string"], [code, filename]);
  if (ok !== 0) { status.textContent = `failed to load ${filename}`; return; }
  requestAnimationFrame(frame);
  hostLoop();
}

document.getElementById("file").addEventListener("change", async (e) => {
  const f = e.target.files[0];
  if (f) run(await f.text(), f.name);
});

const params = new URLSearchParams(window.location.search);
const script = params.get("script");
if (script) {
  const res = await fetch(script);
  if (res.ok) run(await res.text(), script.split("/").pop());
  else status.textContent = `cannot fetch ${script}`;
} else {
  status.textContent = "pick a .rb file, or open ?script=../ruby/examples/draw.rb";
}
