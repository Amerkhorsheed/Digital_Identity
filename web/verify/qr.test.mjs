// Locks the QR encoder against known-good symbols.
//
//   node web/verify/qr.test.mjs
//
// The fixtures in qr.fixtures.json were produced by the reference `qrcode`
// package and cover versions 3 through 19 in byte mode at error-correction
// level M — the shape every identity card uses. Each expected symbol was also
// round-tripped through an independent decoder before being recorded here.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { encodeQr } from './qr.js';

const here = dirname(fileURLToPath(import.meta.url));
const fixtures = JSON.parse(
  readFileSync(join(here, 'qr.fixtures.json'), 'utf8'),
);

let failures = 0;

for (const fixture of fixtures) {
  const version = (fixture.size - 17) / 4;
  let actual;
  try {
    actual = encodeQr(fixture.text);
  } catch (error) {
    console.error(`✗ v${version}: threw ${error.message}`);
    failures++;
    continue;
  }

  if (actual.size !== fixture.size) {
    console.error(`✗ v${version}: size ${actual.size}, expected ${fixture.size}`);
    failures++;
    continue;
  }

  let diff = 0;
  for (let r = 0; r < fixture.size; r++) {
    for (let c = 0; c < fixture.size; c++) {
      if (actual.modules[r][c] !== (fixture.rows[r][c] === '1' ? 1 : 0)) diff++;
    }
  }

  if (diff > 0) {
    console.error(`✗ v${version}: ${diff} modules differ`);
    failures++;
  } else {
    console.log(`✓ v${version} (${fixture.size}×${fixture.size})`);
  }
}

if (failures > 0) {
  console.error(`\n${failures} of ${fixtures.length} fixtures failed`);
  process.exit(1);
}
console.log(`\nall ${fixtures.length} fixtures match`);
