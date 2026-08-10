// Strudel Extractor — zero-dependency local server.
// Usage: node tools/strudel_extractor/server.mjs [--in <dir>] [--out <dir>] [--port 8123]
// Serves the tool page + vendored libs, lists .strudel files from --in,
// and writes rendered audio into --out. Nothing else. No npm dependencies.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const TOOL_DIR = path.dirname(fileURLToPath(import.meta.url));
// Defaults resolve from the repo root (two levels up from tools/strudel_extractor/).
const REPO_ROOT = path.resolve(TOOL_DIR, '..', '..');

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const IN_DIR = path.resolve(REPO_ROOT, arg('in', 'TDD/sound'));
const OUT_DIR = path.resolve(REPO_ROOT, arg('out', 'assets/audio'));
const PORT = parseInt(arg('port', '8123'), 10);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.css': 'text/css',
  '.wasm': 'application/wasm',
  '.map': 'application/json',
  '.mts': 'text/plain',
  '.md': 'text/plain; charset=utf-8',
};

// A filename is safe if it has no path separators and doesn't start with a dot.
const safeName = (n) => n && !n.includes('/') && !n.includes('\\') && !n.startsWith('.') && !n.includes('..');

function sendFile(res, filePath) {
  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end('not found'); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(filePath)] ?? 'application/octet-stream' });
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const p = url.pathname;

  if (req.method === 'GET') {
    if (p === '/' || p === '/index.html') return sendFile(res, path.join(TOOL_DIR, 'ui', 'index.html'));
    if (p === '/app.js' || p === '/recorder.worklet.js') return sendFile(res, path.join(TOOL_DIR, 'ui', p.slice(1)));
    if (p.startsWith('/vendor/')) {
      const rel = p.slice('/vendor/'.length);
      if (rel.split('/').every(safeName)) return sendFile(res, path.join(TOOL_DIR, 'vendor', rel));
      res.writeHead(400); return res.end('bad path');
    }
    if (p === '/config') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ inDir: IN_DIR, outDir: OUT_DIR }));
    }
    if (p === '/files') {
      fs.readdir(IN_DIR, (err, names) => {
        if (err) { res.writeHead(500); return res.end(JSON.stringify({ error: `cannot read ${IN_DIR}` })); }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(names.filter((n) => n.endsWith('.strudel')).sort()));
      });
      return;
    }
    if (p.startsWith('/file/')) {
      const name = decodeURIComponent(p.slice('/file/'.length));
      if (!safeName(name) || !name.endsWith('.strudel')) { res.writeHead(400); return res.end('bad name'); }
      return sendFile(res, path.join(IN_DIR, name));
    }
  }

  if (req.method === 'POST' && p === '/save') {
    const name = url.searchParams.get('name');
    if (!safeName(name) || !/\.(wav|ogg)$/.test(name)) { res.writeHead(400); return res.end('bad name'); }
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > 512 * 1024 * 1024) { req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => {
      fs.mkdirSync(OUT_DIR, { recursive: true });
      const target = path.join(OUT_DIR, name);
      if (!target.startsWith(OUT_DIR + path.sep)) { res.writeHead(400); return res.end('bad path'); }
      fs.writeFile(target, Buffer.concat(chunks), (err) => {
        if (err) { res.writeHead(500); return res.end(err.message); }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ saved: target, bytes: size }));
      });
    });
    return;
  }

  res.writeHead(404);
  res.end('not found');
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Strudel Extractor`);
  console.log(`  in:  ${IN_DIR}`);
  console.log(`  out: ${OUT_DIR}`);
  console.log(`  →  http://localhost:${PORT}`);
});
