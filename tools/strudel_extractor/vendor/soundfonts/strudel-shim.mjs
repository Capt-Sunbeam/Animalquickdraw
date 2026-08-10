// Shim: re-exports the names @strudel/soundfonts imports from "@strudel/core" and
// "@strudel/webaudio" out of the vendored @strudel/web IIFE bundle (window.strudel).
// Both bare specifiers are mapped here by the import map in ui/index.html, so the
// soundfont registry lands in the SAME engine instance the extractor plays through
// (a second bundled copy would register gm_* sounds into an engine nobody uses).
// Load order: ui/index.html loads vendor/strudel-web.js with a classic <script> tag
// before any module executes, so window.strudel is always set by the time this runs.
const s = window.strudel;
if (!s) throw new Error('strudel-shim: vendor/strudel-web.js must load first');

// from @strudel/core
export const { freqToMidi, noteToMidi, getSoundIndex, Pattern, getPlayableNoteValue } = s;
// from @strudel/webaudio
export const {
  registerSound,
  getADSRValues,
  getAudioContext,
  getParamADSR,
  getVibratoOscillator,
  getPitchEnvelope,
  onceEnded,
  releaseAudioNode,
} = s;
