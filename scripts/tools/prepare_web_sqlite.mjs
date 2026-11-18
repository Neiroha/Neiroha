import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';

const driftVersion = '2.35.2';
const releaseUrl = `https://github.com/simolus3/drift/releases/download/drift-${driftVersion}/`;
const lock = await readFile(new URL('../../pubspec.lock', import.meta.url), 'utf8');
const lockedDrift = lock.match(/^  drift:\r?\n[\s\S]*?^    version: "([^"]+)"/m)?.[1];
if (lockedDrift !== driftVersion) {
  throw new Error(`Update the pinned Web SQLite runtime for Drift ${lockedDrift}.`);
}

const assets = {
  'sqlite3.wasm': 'fbcd2e8214f9231ea961e1b7706a22dd1194cfbfe6f26f13841b5aa7a0be1a1f',
  'drift_worker.js': '191fc9db018d2bbecb1723e81118fcf2c5c094df8644c2fcba2ed51df061e90a',
};
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');

for (const [name, sha256] of Object.entries(assets)) {
  const output = new URL(`../../web/${name}`, import.meta.url);
  const existing = await readFile(output).catch(error => {
    if (error.code !== 'ENOENT') throw error;
    return null;
  });
  if (existing && digest(existing) === sha256) continue;
  const response = await fetch(new URL(name, releaseUrl), {
    signal: AbortSignal.timeout(60_000),
  });
  if (!response.ok) throw new Error(`Could not download ${name} (HTTP ${response.status}).`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (digest(bytes) !== sha256) throw new Error(`SHA-256 mismatch for ${name}.`);
  await writeFile(output, bytes);
}
