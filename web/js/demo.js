// Local demo frames so recording can be tried without a physical camera.
// Produces plausible 256x192 dual-plane frames through the same deliverFrame()
// path the real camera uses — no protocol or rendering code is touched.
import { deliverFrame } from "./viewer.js";

let timer = null, tick = 0;
export function demoRunning() { return !!timer; }

export function toggleDemo() {
  if (timer) { clearInterval(timer); timer = null; return false; }
  const w = 256, h = 192;
  const ir = new Uint8Array(w * h);
  const thermal = new Uint16Array(w * h);
  timer = setInterval(() => {
    for (let i = 0; i < w * h; i++) {
      const x = i % w, y = (i / w) | 0;
      const blobX = 70 + Math.sin(tick / 22) * 55;
      const blobY = 95 + Math.cos(tick / 31) * 45;
      const d = Math.hypot(x - blobX, y - blobY);
      const hot = Math.max(0, 1 - d / 46);
      const ambient = 0.35 + 0.12 * Math.sin((x + y) / 40 + tick / 18);
      ir[i] = Math.min(255, (ambient + hot * 0.7) * 255) | 0;
      const k = (273.15 + 22 + hot * 38) * 64;   // kelvin * 64, as the device sends
      thermal[i] = k | 0;
    }
    deliverFrame(w, h, ir, thermal);
    tick++;
  }, 40);
  return true;
}
