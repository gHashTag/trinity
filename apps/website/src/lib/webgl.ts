// Can this browser create a WebGL context at all?
//
// Measured 2026-10-03 on a Chromium with no GPU (the remote browser pod on
// Railway, Chrome 151 on Linux): getContext('webgl2') and getContext('webgl')
// both answer null, Babylon's Engine constructor throws "WebGL not supported",
// and with no boundary above the landing's comb that throw unmounted the whole
// React tree. t27.ai/ was a blank page for anyone without WebGL, although
// everything on it except one panel had nothing to do with WebGL.
//
// Asked once per page and remembered: the answer does not change while the
// document lives, and every probe is a context the browser has to grant.
//
// The probe's context is released at once. Safari counts contexts per page and
// evicts the oldest to serve a new request (see QueenCombBabylon), so a probe
// left alive would be a context the real scene pays for.
let answer: boolean | null = null

export function webglAvailable(): boolean {
  if (answer === null) answer = probe()
  return answer
}

function probe(): boolean {
  if (typeof document === 'undefined') return false
  try {
    // The same order Babylon asks in: webgl2 first, then webgl. A canvas whose
    // first request answered null has no context mode yet, so the second
    // request on it is a real question, not a mismatch.
    const canvas = document.createElement('canvas')
    const gl = canvas.getContext('webgl2') ?? canvas.getContext('webgl')
    if (!gl) return false
    gl.getExtension('WEBGL_lose_context')?.loseContext()
    return true
  } catch {
    // Some browsers throw instead of answering null when the GPU is blocklisted.
    return false
  }
}
