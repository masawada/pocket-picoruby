// Shared by the browser runner (runner.ts) and the headless runner
// (scripts/run-rb.ts): the screen geometry, the gamepad bits and the shape of
// the Emscripten module built from runner.c by scripts/build-wasm.sh.

export const WIDTH = 266;
export const HEIGHT = 240;

// Bit positions as in Pocket::Input.
export const BUTTONS = {
  UP: 1 << 0, DOWN: 1 << 1, LEFT: 1 << 2, RIGHT: 1 << 3,
  A: 1 << 4, B: 1 << 5, X: 1 << 6, Y: 1 << 7,
  L1: 1 << 8, R1: 1 << 9, L2: 1 << 10, R2: 1 << 11, L3: 1 << 12, R3: 1 << 13,
  SELECT: 1 << 14, START: 1 << 15,
} as const;
export type Button = keyof typeof BUTTONS;

// The functions listed in EXPORTED_FUNCTIONS / EXPORTED_RUNTIME_METHODS in
// scripts/build-wasm.sh.
export interface PocketModule {
  HEAPU8: Uint8Array;
  ccall(
    name: "pocket_wasm_init" | "pocket_wasm_load",
    returnType: "number",
    argTypes: ("string" | "number")[],
    args: (string | number)[],
  ): number;
  _malloc(size: number): number;
  _free(ptr: number): void;
  _pocket_wasm_tick(): void;
  _pocket_wasm_step(): number;
  _pocket_wasm_alive(): number;
  _pocket_host_vblank(): void;
  _pocket_host_set_keys(keys: number): void;
  _pocket_host_framebuffer(): number;
  _pocket_host_render_audio(ptr: number, frames: number): void;
}

export interface PocketModuleOptions {
  print?: (text: string) => void;
  printErr?: (text: string) => void;
}

export type CreatePocketModule = (options?: PocketModuleOptions) => Promise<PocketModule>;
