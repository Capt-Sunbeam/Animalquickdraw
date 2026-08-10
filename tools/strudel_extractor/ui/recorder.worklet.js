// Strudel Extractor — recorder worklet.
// Sits on the tap chain permanently; only copies frames out while `recording`.
// Each posted batch carries `frame` = the AudioContext frame index of its first
// sample (from the worklet-global `currentFrame`), which is what makes clock-based
// slicing exact: sample N of the capture is context time (firstFrame + N) / sampleRate.
class RecorderProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.recording = false;
    this.batch = [];
    this.batchFrame = 0;
    this.port.onmessage = (e) => {
      if (e.data === 'start') { this.recording = true; this.batch = []; }
      else if (e.data === 'stop') { this.flush(); this.recording = false; }
    };
  }

  flush() {
    if (!this.batch.length) return;
    const blocks = this.batch;
    this.batch = [];
    const total = blocks.reduce((n, b) => n + b[0].length, 0);
    const l = new Float32Array(total);
    const r = new Float32Array(total);
    let off = 0;
    for (const [bl, br] of blocks) { l.set(bl, off); r.set(br, off); off += bl.length; }
    this.port.postMessage({ frame: this.batchFrame, l, r }, [l.buffer, r.buffer]);
  }

  process(inputs) {
    const input = inputs[0];
    if (this.recording && input && input.length) {
      if (!this.batch.length) this.batchFrame = currentFrame;
      const ch0 = input[0];
      const ch1 = input[1] ?? input[0]; // mono input duplicates to both channels
      this.batch.push([Float32Array.from(ch0), Float32Array.from(ch1)]);
      if (this.batch.length >= 32) this.flush(); // ~85 ms per message at 128-frame blocks
    }
    return true; // keep alive for the whole session
  }
}

registerProcessor('extractor-recorder', RecorderProcessor);
