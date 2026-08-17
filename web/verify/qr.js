// Minimal QR Code encoder — byte mode, error-correction level M.
//
// The verifier page redraws the identity card, and the card's back carries a
// QR code, so the page needs to produce one. This is a from-scratch, no
// dependency implementation of ISO/IEC 18004 restricted to what the card
// needs: 8-bit byte mode, level M, versions 1–20.
//
// Its output is locked module-for-module against reference symbols in
// qr.fixtures.json — run `node web/verify/qr.test.mjs`.

export function encodeQr(text, forceMask = null) {
  const data = new TextEncoder().encode(text);
  const version = pickVersion(data.length);
  const size = version * 4 + 17;

  const codewords = buildCodewords(data, version);
  const { matrix, reserved } = buildTemplate(version, size);

  placeData(matrix, reserved, codewords, size);

  let best = null;
  for (let mask = 0; mask < 8; mask++) {
    if (forceMask !== null && mask !== forceMask) continue;
    const candidate = matrix.map((row) => row.slice());
    applyMask(candidate, reserved, mask, size);
    writeFormat(candidate, mask, size);
    if (version >= 7) writeVersion(candidate, version, size);
    const score = penalty(candidate, size);
    if (best === null || score < best.score) best = { score, candidate, mask };
  }

  return { size, modules: best.candidate, mask: best.mask };
}

// ---------------------------------------------------------------- capacities

// Data codewords available at level M, versions 1–20.
const DATA_CODEWORDS_M = [
  16, 28, 44, 64, 86, 108, 124, 154, 182, 216, 254, 290, 334, 365, 415, 453,
  507, 563, 627, 669,
];

// [ec codewords per block, group1 blocks, group2 blocks] at level M.
const BLOCKS_M = [
  [10, 1, 0], [16, 1, 0], [26, 1, 0], [18, 2, 0], [24, 2, 0], [16, 4, 0],
  [18, 4, 0], [22, 2, 2], [22, 3, 2], [26, 4, 1], [30, 1, 4], [22, 6, 2],
  [22, 8, 1], [24, 4, 5], [24, 5, 5], [28, 7, 3], [28, 10, 1], [26, 9, 4],
  [26, 3, 11], [26, 3, 13],
];

// Alignment-pattern centre coordinates, versions 1–20. Version 1 has none.
const ALIGNMENT = [
  [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34], [6, 22, 38],
  [6, 24, 42], [6, 26, 46], [6, 28, 50], [6, 30, 54], [6, 32, 58],
  [6, 34, 62], [6, 26, 46, 66], [6, 26, 48, 70], [6, 26, 50, 74],
  [6, 30, 54, 78], [6, 30, 56, 82], [6, 30, 58, 86], [6, 34, 62, 90],
];

function pickVersion(byteLength) {
  for (let version = 1; version <= 20; version++) {
    const countBits = version < 10 ? 8 : 16;
    const capacityBits = DATA_CODEWORDS_M[version - 1] * 8;
    if (4 + countBits + byteLength * 8 <= capacityBits) return version;
  }
  throw new Error('payload too large for a level-M QR code');
}

// ------------------------------------------------------------------ GF(256)

const EXP = new Uint8Array(512);
const LOG = new Uint8Array(256);
(function initTables() {
  let x = 1;
  for (let i = 0; i < 255; i++) {
    EXP[i] = x;
    LOG[x] = i;
    x <<= 1;
    if (x & 0x100) x ^= 0x11d;
  }
  for (let i = 255; i < 512; i++) EXP[i] = EXP[i - 255];
})();

function gfMul(a, b) {
  if (a === 0 || b === 0) return 0;
  return EXP[LOG[a] + LOG[b]];
}

function generatorPoly(degree) {
  let poly = [1];
  for (let i = 0; i < degree; i++) {
    const next = new Array(poly.length + 1).fill(0);
    for (let j = 0; j < poly.length; j++) {
      next[j] ^= poly[j];
      next[j + 1] ^= gfMul(poly[j], EXP[i]);
    }
    poly = next;
  }
  return poly;
}

function ecCodewords(block, count) {
  const gen = generatorPoly(count);
  const buffer = [...block, ...new Array(count).fill(0)];
  for (let i = 0; i < block.length; i++) {
    const factor = buffer[i];
    if (factor === 0) continue;
    for (let j = 0; j < gen.length; j++) {
      buffer[i + j] ^= gfMul(gen[j], factor);
    }
  }
  return buffer.slice(block.length);
}

// -------------------------------------------------------------- data stream

function buildCodewords(data, version) {
  const totalData = DATA_CODEWORDS_M[version - 1];
  const countBits = version < 10 ? 8 : 16;

  const bits = [];
  const push = (value, length) => {
    for (let i = length - 1; i >= 0; i--) bits.push((value >> i) & 1);
  };

  push(0b0100, 4); // byte mode
  push(data.length, countBits);
  for (const byte of data) push(byte, 8);

  // Terminator, then pad to a byte boundary, then alternating pad bytes.
  const capacityBits = totalData * 8;
  push(0, Math.min(4, capacityBits - bits.length));
  while (bits.length % 8 !== 0) bits.push(0);

  const bytes = [];
  for (let i = 0; i < bits.length; i += 8) {
    let byte = 0;
    for (let j = 0; j < 8; j++) byte = (byte << 1) | bits[i + j];
    bytes.push(byte);
  }
  const PAD = [0xec, 0x11];
  for (let i = 0; bytes.length < totalData; i++) bytes.push(PAD[i % 2]);

  // Split into blocks, compute EC, then interleave both sets.
  const [ecPerBlock, group1, group2] = BLOCKS_M[version - 1];
  const blockCount = group1 + group2;
  const shortLength = Math.floor(totalData / blockCount);

  const dataBlocks = [];
  const ecBlocks = [];
  let offset = 0;
  for (let i = 0; i < blockCount; i++) {
    const length = i < group1 ? shortLength : shortLength + 1;
    const block = bytes.slice(offset, offset + length);
    offset += length;
    dataBlocks.push(block);
    ecBlocks.push(ecCodewords(block, ecPerBlock));
  }

  const result = [];
  const maxData = Math.max(...dataBlocks.map((b) => b.length));
  for (let i = 0; i < maxData; i++) {
    for (const block of dataBlocks) if (i < block.length) result.push(block[i]);
  }
  for (let i = 0; i < ecPerBlock; i++) {
    for (const block of ecBlocks) result.push(block[i]);
  }
  return result;
}

// ------------------------------------------------------------ function areas

function buildTemplate(version, size) {
  const matrix = Array.from({ length: size }, () => new Array(size).fill(0));
  const reserved = Array.from({ length: size }, () =>
    new Array(size).fill(false),
  );

  const setArea = (row, col, height, width, fill) => {
    for (let r = 0; r < height; r++) {
      for (let c = 0; c < width; c++) {
        const rr = row + r;
        const cc = col + c;
        if (rr < 0 || cc < 0 || rr >= size || cc >= size) continue;
        reserved[rr][cc] = true;
        if (fill) matrix[rr][cc] = fill(r, c);
      }
    }
  };

  const finder = (row, col) => {
    // Separator first, then the 7×7 eye: dark border, light ring, dark core.
    setArea(row - 1, col - 1, 9, 9, () => 0);
    setArea(row, col, 7, 7, (r, c) => {
      const ring = Math.max(Math.abs(r - 3), Math.abs(c - 3));
      return ring === 2 ? 0 : 1;
    });
  };

  finder(0, 0);
  finder(0, size - 7);
  finder(size - 7, 0);

  // Timing patterns.
  for (let i = 8; i < size - 8; i++) {
    matrix[6][i] = i % 2 === 0 ? 1 : 0;
    matrix[i][6] = i % 2 === 0 ? 1 : 0;
    reserved[6][i] = true;
    reserved[i][6] = true;
  }

  // Alignment patterns, skipping the three finder corners.
  const centers = ALIGNMENT[version - 1];
  for (const row of centers) {
    for (const col of centers) {
      const nearFinder =
        (row <= 8 && col <= 8) ||
        (row <= 8 && col >= size - 9) ||
        (row >= size - 9 && col <= 8);
      if (nearFinder) continue;
      setArea(row - 2, col - 2, 5, 5, (r, c) => {
        const ring = Math.max(Math.abs(r - 2), Math.abs(c - 2));
        return ring === 1 ? 0 : 1;
      });
    }
  }

  // Format information areas, and the always-dark module.
  for (let i = 0; i < 9; i++) {
    if (i !== 6) {
      reserved[8][i] = true;
      reserved[i][8] = true;
    }
  }
  for (let i = 0; i < 8; i++) {
    reserved[8][size - 1 - i] = true;
    reserved[size - 1 - i][8] = true;
  }
  matrix[size - 8][8] = 1;
  reserved[size - 8][8] = true;

  if (version >= 7) {
    for (let i = 0; i < 6; i++) {
      for (let j = 0; j < 3; j++) {
        reserved[size - 11 + j][i] = true;
        reserved[i][size - 11 + j] = true;
      }
    }
  }

  return { matrix, reserved };
}

function placeData(matrix, reserved, codewords, size) {
  let bitIndex = 0;
  const totalBits = codewords.length * 8;
  let upward = true;

  for (let right = size - 1; right > 0; right -= 2) {
    if (right === 6) right = 5; // the vertical timing column is skipped
    for (let step = 0; step < size; step++) {
      const row = upward ? size - 1 - step : step;
      for (let c = 0; c < 2; c++) {
        const col = right - c;
        if (reserved[row][col]) continue;
        let bit = 0;
        if (bitIndex < totalBits) {
          bit = (codewords[bitIndex >> 3] >> (7 - (bitIndex & 7))) & 1;
          bitIndex++;
        }
        matrix[row][col] = bit;
      }
    }
    upward = !upward;
  }
}

// ------------------------------------------------------------------- masking

const MASKS = [
  (r, c) => (r + c) % 2 === 0,
  (r) => r % 2 === 0,
  (r, c) => c % 3 === 0,
  (r, c) => (r + c) % 3 === 0,
  (r, c) => (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0,
  (r, c) => ((r * c) % 2) + ((r * c) % 3) === 0,
  (r, c) => (((r * c) % 2) + ((r * c) % 3)) % 2 === 0,
  (r, c) => (((r + c) % 2) + ((r * c) % 3)) % 2 === 0,
];

function applyMask(matrix, reserved, mask, size) {
  const fn = MASKS[mask];
  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      if (reserved[r][c]) continue;
      if (fn(r, c)) matrix[r][c] ^= 1;
    }
  }
}

function writeFormat(matrix, mask, size) {
  // Level M is 0b00; append the mask, then a 10-bit BCH check.
  const value = (0b00 << 3) | mask;
  let bits = value << 10;
  for (let i = 4; i >= 0; i--) {
    if (bits & (1 << (i + 10))) bits ^= 0b10100110111 << i;
  }
  const format = ((value << 10) | bits) ^ 0b101010000010010;

  // The 15 bits are written most-significant first along each copy.
  const bit = (i) => (format >> (14 - i)) & 1;

  // Copy one wraps the top-left eye: along row 8, then up column 8.
  const first = [
    [8, 0], [8, 1], [8, 2], [8, 3], [8, 4], [8, 5], [8, 7], [8, 8],
    [7, 8], [5, 8], [4, 8], [3, 8], [2, 8], [1, 8], [0, 8],
  ];

  // Copy two mirrors it: up column 8 from the bottom edge, then along row 8
  // to the right edge. The module at (size - 8, 8) is not part of it — it is
  // the always-dark module.
  const second = [];
  for (let i = 0; i <= 6; i++) second.push([size - 1 - i, 8]);
  for (let i = 0; i < 8; i++) second.push([8, size - 8 + i]);

  for (const positions of [first, second]) {
    positions.forEach(([r, c], i) => {
      matrix[r][c] = bit(i);
    });
  }
}

function writeVersion(matrix, version, size) {
  let bits = version << 12;
  for (let i = 5; i >= 0; i--) {
    if (bits & (1 << (i + 12))) bits ^= 0b1111100100101 << i;
  }
  const info = (version << 12) | bits;
  for (let i = 0; i < 18; i++) {
    const bit = (info >> i) & 1;
    const row = Math.floor(i / 3);
    const col = size - 11 + (i % 3);
    matrix[row][col] = bit;
    matrix[col][row] = bit;
  }
}

// ------------------------------------------------------------------ penalty

function penalty(matrix, size) {
  let score = 0;

  const run = (get) => {
    for (let a = 0; a < size; a++) {
      let last = -1;
      let length = 0;
      for (let b = 0; b < size; b++) {
        const value = get(a, b);
        if (value === last) {
          length++;
        } else {
          if (length >= 5) score += length - 2;
          last = value;
          length = 1;
        }
      }
      if (length >= 5) score += length - 2;
    }
  };
  run((r, c) => matrix[r][c]);
  run((c, r) => matrix[r][c]);

  for (let r = 0; r < size - 1; r++) {
    for (let c = 0; c < size - 1; c++) {
      const v = matrix[r][c];
      if (
        v === matrix[r][c + 1] &&
        v === matrix[r + 1][c] &&
        v === matrix[r + 1][c + 1]
      ) {
        score += 3;
      }
    }
  }

  const PATTERNS = [
    [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1],
  ];
  const scanPattern = (get) => {
    for (let a = 0; a < size; a++) {
      for (let b = 0; b <= size - 11; b++) {
        for (const pattern of PATTERNS) {
          let match = true;
          for (let k = 0; k < 11; k++) {
            if (get(a, b + k) !== pattern[k]) {
              match = false;
              break;
            }
          }
          if (match) score += 40;
        }
      }
    }
  };
  scanPattern((r, c) => matrix[r][c]);
  scanPattern((c, r) => matrix[r][c]);

  let dark = 0;
  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) dark += matrix[r][c];
  }
  const percent = (dark * 100) / (size * size);
  score += Math.floor(Math.abs(percent - 50) / 5) * 10;

  return score;
}
