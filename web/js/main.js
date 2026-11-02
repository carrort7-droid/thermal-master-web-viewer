// Entry point: connect to the camera and pump frames into the viewer.

import { Camera } from "./usb.js";
import { session } from "./session.js";
import { els, state, deliverFrame } from "./viewer.js";
import { startCapture, stopCapture } from "./log.js";
import { keepAwake, wakeStatus } from "./wakelock.js";
import "./ui.js";
import "./panels.js";

const statusEl = els("status");
const connectBtn = els("connect");

function setStatus(text, cls = "") {
  statusEl.textContent = text;
  statusEl.className = cls;
}

// --- driver-install help -------------------------------------------------
// The card is shown ONLY when a connect failed specifically while claiming a
// USB interface (the Windows "driver not installed" symptom: a device the
// browser can see and select but cannot open — Device Manager ProblemCode 28).
// Failures at any other stage (read info, start stream, mid-stream disconnect)
// must NOT trigger it, so we key off the `claimFailed` flag set in usb.js.
function showDriverHelp() {
  const card = document.getElementById("driverHelp");
  if (card) card.hidden = false;
}
function hideDriverHelp() {
  const card = document.getElementById("driverHelp");
  if (card) card.hidden = true;
}
function reportError(err) {
  const msg = `${err && err.name ? err.name : "Error"}: ${err && err.message ? err.message : String(err)}`;
  setStatus(msg, "err");
  connectBtn.hidden = false;
  session.cam = null;
  keepAwake(false);
  if (err && err.claimFailed) showDriverHelp();
}

async function run(cam) {
  session.cam = cam;
  connectBtn.hidden = true;
  hideDriverHelp();
  try {
    await cam.open(setStatus);
    state.info = await cam.readInfo();
    els("modelName").textContent = state.info.model_long || cam.name;
    await cam.startStream(setStatus);
    setStatus("live", "live");
    startCapture();   // record the firmware log from now on, panel open or not
    startMeta();
    keepAwake(true);  // a phone locking mid-measurement helps nobody
  } catch (err) {
    // Release a half-open device / claimed interface. A claimInterface that
    // timed out can still be in flight underneath (a promise cannot be
    // cancelled), so closing best-effort leaves the next attempt clean.
    // Fire-and-forget: never block the error path on a wedged device.
    if (cam && typeof cam.close === "function") {
      try { cam.close().catch(() => {}); } catch {}
    }
    reportError(err);
    return;
  }

  while (cam.streaming) {
    try {
      const f = await cam.readFrame();
      deliverFrame(f.w, f.h, f.ir, f.thermal);
    } catch (err) {
      if (!cam.streaming) break;
      if (err.name === "NotFoundError" || err.name === "NetworkError") {
        setStatus("camera disconnected", "err");
        connectBtn.hidden = false;
        stopCapture();
        stopMeta();
        keepAwake(false);
        session.cam = null;
        return;
      }
      // A marker mismatch just means we caught a frame mid-flight; read on.
    }
  }
  keepAwake(false);
}

// One connect flow at a time. The button is only hidden after the picker
// resolves, so without this a double-click would open two flows against the
// same device and fight over its interfaces.
let connecting = false;

connectBtn.onclick = async () => {
  if (connecting) return;
  connecting = true;
  connectBtn.disabled = true;
  try {
    await run(await Camera.request());
  } catch (err) {
    if (err.name !== "NotFoundError") setStatus(`${err.name}: ${err.message}`, "err");
  } finally {
    connecting = false;
    connectBtn.disabled = false;
  }
};

// Driver-help card close button (card is an overlay, independent of other UI state).
const driverCloseBtn = document.getElementById("driverClose");
if (driverCloseBtn) driverCloseBtn.onclick = hideDriverHelp;

function showMeta(extra) {
  const rows = Object.entries({
    ...extra,
    "client fps": state.fps.toFixed(1),
    "screen lock": wakeStatus(),
    firmware: state.info?.fw_version,
    serial: state.info?.serial,
  }).filter(([, v]) => v !== undefined && v !== null && v !== "");
  els("deviceMeta").innerHTML = rows.map(([k, v]) => `<div>${k}: ${v}</div>`).join("");
}

// Only tick while a camera is attached; there is nothing to report otherwise.
let metaTimer = null;

function startMeta() {
  stopMeta();
  metaTimer = setInterval(() => {
    if (session.cam) showMeta({ frames: session.cam.frames, dropped: session.cam.dropped });
  }, 1000);
}

function stopMeta() {
  clearInterval(metaTimer);
  metaTimer = null;
}

async function start() {
  if (!Camera.supported()) {
    connectBtn.hidden = true;
    setStatus("WebUSB needed — use Chrome or Edge", "err");
    return;
  }
  // Reconnect silently if this browser already has permission for the camera.
  try {
    const [known] = await Camera.paired();
    if (known) { run(known); return; }
  } catch {}
  setStatus("not connected");
}

start();
