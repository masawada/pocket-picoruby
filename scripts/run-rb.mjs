#!/usr/bin/env node
// Run a Ruby script headlessly on the wasm build (web/dist/pocket-node.js).
//
//   node scripts/run-rb.mjs path/to/script.rb [--frames N] [--timeout MS]
//
// The screen is not shown; vblank is raised every 16 ms of wall time so
// Pocket.wait_vsync paces the script like the device. Exit status is 1 when a
// task raised, 2 on timeout. --frames stops after N vblanks (for scripts that
// loop forever, such as ruby/examples/draw.rb).

import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

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
process.exit(raised ? 1 : 0);
