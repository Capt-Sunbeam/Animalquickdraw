// ESM wrapper: soundfont2@0.4.0 ships only a webpack UMD bundle (sets
// window.SoundFont2 = <module namespace>). Importing it for side effects under
// ESM leaves `module`/`exports`/`define` undefined, so the UMD takes its global
// branch — then we re-export the two names sfumato imports.
import './soundfont2.umd.js';
const ns = window.SoundFont2;
if (!ns?.SoundFont2) throw new Error('soundfont2 UMD global missing');
export const SoundFont2 = ns.SoundFont2;
export const DEFAULT_GENERATOR_VALUES = ns.DEFAULT_GENERATOR_VALUES;
export default ns;
