// Browser runner: canvas as the Pocket's screen, keyboard as the gamepad.
// Loads dist/pocket.js (built by scripts/build-wasm.sh).

import createModule from "./dist/pocket.js";
import { BUTTONS, HEIGHT, WIDTH, type PocketModule } from "./pocket.ts";

const MRB_TICK_UNIT = 1;      // must match build_config/pocket-wasm.rb
const BATCH_DURATION = 12;    // ms of VM time per host-loop pass
const MAX_CATCHUP_TICKS = 20;

const KEYMAP: Record<string, number> = {
  ArrowUp: BUTTONS.UP, ArrowDown: BUTTONS.DOWN, ArrowLeft: BUTTONS.LEFT, ArrowRight: BUTTONS.RIGHT,
  KeyZ: BUTTONS.A,
  KeyX: BUTTONS.B,
  KeyA: BUTTONS.X,
  KeyS: BUTTONS.Y,
  KeyQ: BUTTONS.L1,
  KeyW: BUTTONS.R1,
  ShiftLeft: BUTTONS.SELECT, ShiftRight: BUTTONS.SELECT,
  Enter: BUTTONS.START,
};

function element<T extends HTMLElement>(id: string): T {
  const el = document.getElementById(id);
  if (!el) throw new Error(`#${id} not found`);
  return el as T;
}

function context2d(canvas: HTMLCanvasElement): CanvasRenderingContext2D {
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("2d canvas is not available");
  return ctx;
}

const ctx = context2d(element<HTMLCanvasElement>("screen"));
const image = ctx.createImageData(WIDTH, HEIGHT);
const log = element<HTMLDivElement>("log");
const status = element<HTMLDivElement>("status");
const fileInput = element<HTMLInputElement>("file");

function appendLog(text: string, cls?: string) {
  const line = document.createElement("div");
  line.textContent = text;
  if (cls) line.className = cls;
  log.appendChild(line);
  log.scrollTop = log.scrollHeight;
}

const Module: PocketModule = await createModule({
  print: (t) => appendLog(t),
  printErr: (t) => appendLog(t, "err"),
});

// Audio: the C synth renders 16-bit mono at 48 kHz into wasm memory and a
// ScriptProcessorNode pulls it. Browsers only start audio after a gesture.
let audioStarted = false;
function startAudio() {
  if (audioStarted) return;
  audioStarted = true;
  const audio = new AudioContext({ sampleRate: 48000 });
  const FRAMES = 1024;
  const ptr = Module._malloc(FRAMES * 2);
  const node = audio.createScriptProcessor(FRAMES, 0, 1);
  node.onaudioprocess = (e) => {
    Module._pocket_host_render_audio(ptr, FRAMES);
    const pcm = new Int16Array(Module.HEAPU8.buffer, ptr, FRAMES);
    const out = e.outputBuffer.getChannelData(0);
    for (let i = 0; i < FRAMES; i++) out[i] = pcm[i] / 32768;
  };
  node.connect(audio.destination);
  audio.resume();
}
window.addEventListener("keydown", startAudio, { once: true });
window.addEventListener("pointerdown", startAudio, { once: true });

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

let started = false;
function run(code: string, filename: string) {
  log.textContent = "";
  status.textContent = `running ${filename}`;
  // A fresh VM per script: the simplest way to match "reset core" on the device.
  if (started) {
    window.location.reload();
    return;
  }
  started = true;
  if (Module.ccall("pocket_wasm_init", "number", [], []) !== 0) return;
  const ok = Module.ccall("pocket_wasm_load", "number", ["string", "string"], [code, filename]);
  if (ok !== 0) { status.textContent = `failed to load ${filename}`; return; }
  requestAnimationFrame(frame);
  hostLoop();
}

fileInput.addEventListener("change", async () => {
  const f = fileInput.files?.[0];
  if (f) run(await f.text(), f.name);
});

const params = new URLSearchParams(window.location.search);
const script = params.get("script");
if (script) {
  // The script is what gets edited and re-run, so skip the browser cache
  // rather than serve a stale copy.
  const res = await fetch(script, { cache: "no-store" });
  if (res.ok) run(await res.text(), script.split("/").pop() ?? script);
  else status.textContent = `cannot fetch ${script}`;
} else {
  status.textContent = "pick a .rb file, or open ?script=ruby/examples/draw.rb";
}
