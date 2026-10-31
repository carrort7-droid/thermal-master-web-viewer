// Checks the device profile table: known product IDs, the 256x192 fallback,
// and that the vendor id has not drifted.
import { VID, MODELS, DEFAULT_PID, resolveModel } from "../web/js/models.js";

let failures = 0;

function ok(name, fn) {
  try {
    fn();
    console.log("  PASS  " + name);
  } catch (e) {
    failures++;
    console.log("  FAIL  " + name + " -- " + e.message);
  }
}

function eq(actual, expected, label = "") {
  if (actual !== expected) {
    throw new Error(`${label} expected ${expected}, got ${actual}`);
  }
}

ok("vendor id is Thermal Master", () => eq(VID, 0x3474));

ok("P2 Max is a first-class profile", () => {
  const m = resolveModel(0x42b2);
  eq(m.name, "P2 Max", "name");
  eq(m.w, 256, "width");
  eq(m.h, 192, "height");
  eq(m.fallback, false, "fallback");
});

ok("P1 keeps its own resolution", () => {
  const m = resolveModel(0x45c2);
  eq(m.name, "P1", "name");
  eq(m.w, 160, "width");
  eq(m.h, 120, "height");
});

ok("P3 is the 256x192 reference", () => {
  const m = resolveModel(0x45a2);
  eq(m.name, "P3", "name");
  eq(m.w, 256, "width");
  eq(m.h, 192, "height");
});

ok("unknown product id falls back to 256x192", () => {
  const m = resolveModel(0x9999);
  eq(m.w, 256, "width");
  eq(m.h, 192, "height");
  eq(m.fallback, true, "fallback");
  eq(m.pid, 0x9999, "pid");
});

ok("a renamed device is still resolved by product id", () => {
  // Recognition never touches the product string; the PID decides.
  const sameDevice = resolveModel(0x42b2);
  eq(sameDevice.name, "P2 Max");
});

ok("resolving does not mutate the table", () => {
  resolveModel(0xdead);
  eq(Object.keys(MODELS).length, 3, "model count");
  eq(DEFAULT_PID, 0x45a2, "default pid");
});

if (failures) {
  console.log(`\n${failures} failure(s)`);
  process.exit(1);
}
console.log("\nall passed");
