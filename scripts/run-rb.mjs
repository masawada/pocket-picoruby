#!/usr/bin/env node
// Run a Ruby script headlessly on the wasm build (web/dist/pocket-node.js).
//
//   node scripts/run-rb.mjs path/to/script.rb [--frames N] [--timeout MS] [--screenshot out.png] [--press A@30 ...]
//
// The screen is not shown; vblank is raised every 16 ms of wall time so
// Pocket.wait_vsync paces the script like the device. Exit status is 1 when a
// task raised, 2 on timeout. --frames stops after N vblanks (for scripts that
// loop forever, such as ruby/examples/draw.rb). --screenshot writes the final
// framebuffer as a PNG; --press holds a button for two frames from the given
// frame (names as in Pocket::Input), so a scripted run can navigate.

import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { deflateSync } from "node:zlib";

const args = process.argv.slice(2);
const scriptPath = args.find((a) => !a.startsWith("--"));
if (!scriptPath) {
  console.error("usage: node scripts/run-rb.mjs script.rb [--frames N] [--timeout MS]");
  process.exit(64);
}
const opt = (name, dflt) => {
  const i = args.indexOf(name);
  return i >= 0 ? Number(args[i + 1]) : dflt;
};
const maxFrames = opt("--frames", Infinity);
const timeoutMs = opt("--timeout", 60000);
const shotIndex = args.indexOf("--screenshot");
const screenshot = shotIndex >= 0 ? args[shotIndex + 1] : null;

// --press A@30 --press RIGHT@60: hold a button for two frames from that frame.
const BUTTONS = {
  UP: 1 << 0, DOWN: 1 << 1, LEFT: 1 << 2, RIGHT: 1 << 3, A: 1 << 4, B: 1 << 5, X: 1 << 6, Y: 1 << 7,
  L1: 1 << 8, R1: 1 << 9, L2: 1 << 10, R2: 1 << 11, L3: 1 << 12, R3: 1 << 13, SELECT: 1 << 14, START: 1 << 15,
};
const presses = [];
args.forEach((a, i) => {
  if (a !== "--press") return;
  const [name, at] = args[i + 1].split("@");
  if (!(name in BUTTONS)) { console.error(`unknown button ${name}`); process.exit(64); }
  presses.push({ bit: BUTTONS[name], at: Number(at) });
});
function keysAtFrame(frame) {
  let bits = 0;
  for (const p of presses) if (frame >= p.at && frame < p.at + 2) bits |= p.bit;
  return bits;
}

const WIDTH = 266;
const HEIGHT = 240;

function crc32(buf) {
  let c = ~0;
  for (const b of buf) {
    c ^= b;
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
  }
  return ~c >>> 0;
}

function pngChunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

// RGB565 framebuffer -> 8-bit RGB PNG.
function writePng(path, fb) {
  const raw = Buffer.alloc((WIDTH * 3 + 1) * HEIGHT);
  for (let y = 0; y < HEIGHT; y++) {
    raw[y * (WIDTH * 3 + 1)] = 0; // filter: none
    for (let x = 0; x < WIDTH; x++) {
      const p = fb[y * WIDTH + x];
      const o = y * (WIDTH * 3 + 1) + 1 + x * 3;
      raw[o] = Math.round(((p >> 11) & 0x1f) * 255 / 31);
      raw[o + 1] = Math.round(((p >> 5) & 0x3f) * 255 / 63);
      raw[o + 2] = Math.round((p & 0x1f) * 255 / 31);
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(WIDTH, 0);
  ihdr.writeUInt32BE(HEIGHT, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  writeFileSync(path, Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    pngChunk("IHDR", ihdr),
    pngChunk("IDAT", deflateSync(raw)),
    pngChunk("IEND", Buffer.alloc(0)),
  ]));
}

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const createModule = (await import(resolve(root, "web/dist/pocket-node.js"))).default;
const Module = await createModule({
  print: (t) => process.stdout.write(t + "\n"),
  printErr: (t) => process.stderr.write(t + "\n"),
});

if (Module.ccall("pocket_wasm_init", "number", [], []) !== 0) process.exit(1);
const code = readFileSync(scriptPath, "utf8");
if (Module.ccall("pocket_wasm_load", "number", ["string", "string"], [code, scriptPath]) !== 0) {
  process.exit(1);
}

const started = Date.now();
let lastTick = started;
let lastVblank = started;
let frames = 0;
let raised = false;

for (;;) {
  const now = Date.now();
  while (now - lastTick >= 1) {
    Module._pocket_wasm_tick();
    lastTick += 1;
  }
  if (now - lastVblank >= 16) {
    Module._pocket_host_vblank();
    lastVblank = now;
    if (++frames >= maxFrames) break;
    if (presses.length) Module._pocket_host_set_keys(keysAtFrame(frames));
  }
  if (now - started > timeoutMs) {
    console.error(`run-rb: timed out after ${timeoutMs} ms`);
    process.exit(2);
  }

  const s = Module._pocket_wasm_step();
  if (s === 2) raised = true;
  if (!Module._pocket_wasm_alive()) break;
  if (s === 0) await new Promise((r) => setTimeout(r, 1));
}
if (screenshot) {
  const ptr = Module._pocket_host_framebuffer();
  writePng(screenshot, new Uint16Array(Module.HEAPU8.buffer, ptr, WIDTH * HEIGHT));
}
process.exit(raised ? 1 : 0);
