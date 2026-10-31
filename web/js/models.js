// Device profiles for Thermal Master USB thermal cameras.
//
// Recognition is by USB **product ID**, never by the product string. A camera
// whose firmware product string is changed (for example renamed to "P3 LITE")
// is still matched by its PID and behaves exactly as before. Conversely an
// unknown PID still works: `resolveModel()` falls back to the 256x192 profile,
// which is what every P2/P3-class detector streams over USB.
//
// Confirmed against hardware:
//   0x42B2  P2 Max   fw 00.00.01.03  hw P2max-00.01  256x192 @ 25 fps
//   0x45A2  P3                                         256x192 @ 25 fps
//   0x45C2  P1                                         160x120 @ 25 fps

export const VID = 0x3474;

export const MODELS = {
  0x45A2: { name: "P3", w: 256, h: 192 },
  0x45C2: { name: "P1", w: 160, h: 120 },
  0x42B2: { name: "P2 Max", w: 256, h: 192 },
};

// P2, P2 Pro, P3 Lite and any other 256x192 member of the family share this
// frame layout, so they stream correctly through the fallback profile.
export const DEFAULT_PID = 0x45A2;

export function resolveModel(productId) {
  const known = MODELS[productId];
  if (known) return { ...known, pid: productId, fallback: false };
  return { ...MODELS[DEFAULT_PID], pid: productId, fallback: true };
}
