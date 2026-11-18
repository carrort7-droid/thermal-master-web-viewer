// Local-only MP4 recording of the sensor view (no audio, no upload).
// Manual frame pushing via captureStream(0) + requestFrame() keeps the video
// locked to the camera's own frame pace instead of a fixed browser clock.
import { state, view, overlay, setAfterRedraw } from "./viewer.js";
import { download, stamp } from "./download.js";

const MP4 = "video/mp4;codecs=avc1.42E01E";
let rec = null, stream = null, track = null;
let chunks = [], out = null, octx = null;
let active = false, btn = null;

function canvas() {
  if (out) return out;
  out = document.createElement("canvas");
  octx = out.getContext("2d", { alpha: false });
  return out;
}

// Composite the two viewer layers exactly like the PNG export does.
function pushFrame() {
  if (!active || !track) return;
  const c = canvas();
  const w = overlay.width || view.width, h = overlay.height || view.height;
  if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
  octx.imageSmoothingEnabled = state.smooth;
  octx.drawImage(view, 0, 0, w, h);
  octx.drawImage(overlay, 0, 0);
  try { track.requestFrame(); } catch {}
}
setAfterRedraw(pushFrame);

function syncBtn() {
  if (!btn) return;
  btn.textContent = active ? "Stop" : "Record";
  btn.classList.toggle("on", active);
  btn.title = active ? "Stop recording and download MP4" : "Record sensor view to MP4";
}

export function isRecording() { return active; }
export function attachButton(id) { btn = document.getElementById(id); syncBtn(); }

export function startRecording() {
  if (active) return Promise.resolve();
  if (!window.MediaRecorder || !HTMLCanvasElement.prototype.captureStream)
    return Promise.reject(new Error("MediaRecorder / captureStream not supported"));
  const mime = MediaRecorder.isTypeSupported(MP4) ? MP4
    : (MediaRecorder.isTypeSupported("video/mp4") ? "video/mp4" : "");
  if (!mime) return Promise.reject(new Error("MP4 recording not supported in this browser"));

  const c = canvas();
  const w = overlay.width || view.width, h = overlay.height || view.height;
  c.width = w; c.height = h;
  octx.imageSmoothingEnabled = state.smooth;
  octx.drawImage(view, 0, 0, w, h);
  octx.drawImage(overlay, 0, 0);

  stream = c.captureStream(0);
  track = stream.getVideoTracks()[0];
  chunks = [];
  try {
    rec = new MediaRecorder(stream, { mimeType: mime, videoBitsPerSecond: 2_000_000 });
  } catch (e) {
    stream.getTracks().forEach(t => t.stop());
    stream = null; track = null;
    return Promise.reject(e);
  }
  rec.ondataavailable = e => { if (e.data && e.data.size) chunks.push(e.data); };
  rec.onstop = () => {
    const blob = new Blob(chunks, { type: rec.mimeType || "video/mp4" });
    download(`thermal-${stamp()}.mp4`, blob);
    if (stream) stream.getTracks().forEach(t => t.stop());
    rec = null; stream = null; track = null; chunks = [];
    active = false; syncBtn();
  };
  rec.start(300);
  active = true;
  syncBtn();
  try { track.requestFrame(); } catch {}
  return Promise.resolve();
}

// Auto-stop hook: called on freeze and on camera disconnect.
// Deliberately NOT wired to visibilitychange/pagehide — backgrounding keeps recording.
export function stopRecording() {
  if (!active || !rec) return;
  active = false;
  try {
    if (rec.state !== "inactive") { try { rec.requestData(); } catch {} rec.stop(); }
    else if (stream) { stream.getTracks().forEach(t => t.stop()); syncBtn(); }
  } catch {
    if (stream) stream.getTracks().forEach(t => t.stop());
    syncBtn();
  }
}
