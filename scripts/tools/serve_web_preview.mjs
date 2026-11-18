import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { extname, resolve, sep } from 'node:path';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath } from 'node:url';
import { createGzip } from 'node:zlib';

const root = fileURLToPath(new URL('../../build/web', import.meta.url));
const host = '127.0.0.1';
const port = Number(process.env.NEIROHA_WEB_PORT ?? 8080);
const origin = `http://${host}:${port}`;
const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.json': 'application/json',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
};

async function serve(req, res) {
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Cache-Control', 'no-store');
  if (req.headers.host !== `${host}:${port}` || !req.url.startsWith('/')) {
    return res.writeHead(403).end();
  }
  const url = new URL(req.url, origin);
  const path = url.pathname;
  if (url.origin !== origin) return res.writeHead(403).end();

  if (req.method !== 'GET' && req.method !== 'HEAD') {
    return res.writeHead(405, { allow: 'GET, HEAD' }).end();
  }
  const file = resolve(root, path === '/' ? 'index.html' : `.${path}`);
  if (!file.startsWith(root + sep)) return res.writeHead(404).end();
  const info = await stat(file).catch(() => null);
  if (!info?.isFile()) return res.writeHead(404).end();
  const type = contentTypes[extname(file)];
  const gzip = type && info.size >= 1024
    && req.headers['accept-encoding']?.split(',').some(value => value.trim() === 'gzip');
  res.setHeader('Vary', 'Accept-Encoding');
  res.setHeader('Content-Type', type ?? 'application/octet-stream');
  if (gzip) res.setHeader('Content-Encoding', 'gzip');
  else res.setHeader('Content-Length', info.size);
  res.writeHead(200);
  if (req.method === 'HEAD') return res.end();
  const stream = createReadStream(file);
  if (gzip) await pipeline(stream, createGzip(), res);
  else await pipeline(stream, res);
}

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('NEIROHA_WEB_PORT must be a valid port.');
}
for (const file of ['index.html', 'sqlite3.wasm', 'drift_worker.js']) {
  await stat(resolve(root, file)).catch(() => {
    throw new Error('Run prepare_web_sqlite.mjs and build the Flutter Web app first.');
  });
}
createServer((req, res) => {
  serve(req, res).catch(() => {
    if (res.headersSent) res.destroy();
    else res.writeHead(500).end();
  });
}).listen(port, host, () => console.log(origin));
