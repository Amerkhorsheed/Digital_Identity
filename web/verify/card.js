// Redraws the identity card on a canvas, then exports it as PNG or PDF.
//
// The proportions mirror lib/features/idcard/id_card_view.dart, so a card
// downloaded from this page matches the one the app produces.

import { formatWeight } from './payload.js';

const PINE = '#17352F';
const PINE_DEEP = '#0E231F';
const PINE_RAISED = '#1E453C';
const GOLD = '#B9A779';
const GOLD_DEEP = '#8A7443';
const GOLD_GLOW = '#D9C79B';
const GOLD_MIST = '#F6F1E4';
const IVORY = '#FAF7EF';
const INK = '#16211E';
const INK_MUTED = '#5C6B66';

/// Card width used for exports, in CSS pixels before the pixel-ratio scale.
export const CARD_WIDTH = 520;
const GAP = 24;
const MARGIN = 36;
const FOOTER = 34;

export const SHEET_WIDTH = CARD_WIDTH + MARGIN * 2;
export const SHEET_HEIGHT =
  MARGIN * 2 + CARD_WIDTH * 0.625 * 2 + GAP + FOOTER;

let markImage = null;

/// Tinted copies of the crest, keyed by fill colour.
///
/// `mark.png` is the eagle as a pure alpha mask on a white body — the same
/// asset the app uses — so a colour is stamped through it with `source-in`
/// once per colour and reused for every draw.
const markCache = new Map();

export async function loadAssets() {
  await document.fonts.load('400 16px Almarai');
  await document.fonts.load('700 16px Almarai');
  await document.fonts.load('700 16px SpaceMono');
  await document.fonts.ready;

  markImage = await new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = './assets/mark.png';
  });
  markCache.clear();
}

function tintedMark(color) {
  if (!markImage) return null;
  const cached = markCache.get(color);
  if (cached) return cached;

  const off = document.createElement('canvas');
  off.width = markImage.naturalWidth || markImage.width;
  off.height = markImage.naturalHeight || markImage.height;
  const octx = off.getContext('2d');
  octx.drawImage(markImage, 0, 0);
  octx.globalCompositeOperation = 'source-in';
  octx.fillStyle = color;
  octx.fillRect(0, 0, off.width, off.height);

  markCache.set(color, off);
  return off;
}

/// Prints the crest at [width], anchored by its top-left corner, at [alpha].
function drawMark(ctx, color, alpha, x, y, width) {
  const mark = tintedMark(color);
  if (!mark) return;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.drawImage(mark, x, y, width, (width * mark.height) / mark.width);
  ctx.restore();
}

/// Draws both faces plus the footer line onto [canvas] at [scale]×.
export function drawSheet(canvas, card, scale = 3) {
  canvas.width = Math.round(SHEET_WIDTH * scale);
  canvas.height = Math.round(SHEET_HEIGHT * scale);

  const ctx = canvas.getContext('2d');
  ctx.setTransform(scale, 0, 0, scale, 0, 0);
  ctx.textBaseline = 'alphabetic';
  ctx.direction = 'rtl';

  ctx.fillStyle = IVORY;
  ctx.fillRect(0, 0, SHEET_WIDTH, SHEET_HEIGHT);

  const height = CARD_WIDTH * 0.625;
  drawFront(ctx, card, MARGIN, MARGIN, CARD_WIDTH, height);
  drawBack(ctx, card, MARGIN, MARGIN + height + GAP, CARD_WIDTH, height);

  ctx.save();
  ctx.fillStyle = GOLD_DEEP;
  ctx.font = '400 12px Almarai, sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText(
    'إدارة القوى البشرية · وثيقة معتمدة',
    SHEET_WIDTH / 2,
    SHEET_HEIGHT - MARGIN + 6,
  );
  ctx.restore();
}

// -------------------------------------------------------------- front face

function drawFront(ctx, card, x, y, w, h) {
  const radius = w * 0.045;
  const pad = w * 0.04;

  ctx.save();
  roundedRect(ctx, x, y, w, h, radius);
  ctx.clip();

  const gradient = ctx.createLinearGradient(x, y, x + w, y + h);
  gradient.addColorStop(0, PINE_RAISED);
  gradient.addColorStop(0.5, PINE);
  gradient.addColorStop(1, PINE_DEEP);
  ctx.fillStyle = gradient;
  ctx.fillRect(x, y, w, h);

  // The crest, printed large across the face and bleeding off the leading
  // edge, over a soft gold glow — the same backdrop the app's card carries.
  ctx.save();
  const glow = ctx.createRadialGradient(
    x + w * 0.80, y + h * 0.32, 0,
    x + w * 0.80, y + h * 0.32, h * 0.65,
  );
  glow.addColorStop(0, 'rgba(185,167,121,0.16)');
  glow.addColorStop(1, 'rgba(185,167,121,0)');
  ctx.fillStyle = glow;
  ctx.fillRect(x, y, w, h);
  ctx.restore();

  // Leading edge is the right one: the card is set right to left.
  drawMark(ctx, GOLD_GLOW, 0.20, x + w * 0.54, y + h * 0.05, w * 0.52);
  drawMark(ctx, GOLD, 0.10, x - w * 0.29, y + h * 0.62, w * 0.40);

  // A single diagonal light pass, so the surface reads as laminate.
  ctx.save();
  const sheen = ctx.createLinearGradient(x, y, x + w, y + h);
  sheen.addColorStop(0, 'rgba(255,255,255,0.05)');
  sheen.addColorStop(0.45, 'rgba(255,255,255,0)');
  sheen.addColorStop(0.62, 'rgba(0,0,0,0.06)');
  sheen.addColorStop(1, 'rgba(0,0,0,0.20)');
  ctx.fillStyle = sheen;
  ctx.fillRect(x, y, w, h);
  ctx.restore();

  // Hairline gold frame set in from the die cut.
  ctx.save();
  const inset = w * 0.018;
  roundedRect(ctx, x + inset, y + inset, w - inset * 2, h - inset * 2, w * 0.032);
  ctx.strokeStyle = 'rgba(185,167,121,0.30)';
  ctx.lineWidth = 0.9;
  ctx.stroke();
  ctx.restore();

  // Header row: logo, wordmark, verified chip.
  const logoSize = w * 0.082;
  const headerY = y + pad;
  drawLogo(ctx, x + w - pad - logoSize, headerY, logoSize);

  ctx.fillStyle = '#FFFFFF';
  ctx.font = `800 ${w * 0.029}px Almarai, sans-serif`;
  ctx.textAlign = 'right';
  ctx.fillText(
    'إدارة القوى البشرية',
    x + w - pad - logoSize - w * 0.022,
    headerY + logoSize * 0.48,
  );

  ctx.fillStyle = GOLD_GLOW;
  ctx.font = `700 ${w * 0.018}px Almarai, sans-serif`;
  ctx.fillText(
    'رحلة حياة المنتسب',
    x + w - pad - logoSize - w * 0.022,
    headerY + logoSize * 0.88,
  );

  drawChip(ctx, x + pad, headerY, w, 'موثّقة');

  // Name block — the card carries no portrait, so the text runs the full width.
  const baseline = y + h * 0.30 + h * 0.46 * 0.58;
  const textRight = x + w - pad;
  ctx.textAlign = 'right';
  ctx.fillStyle = '#FFFFFF';
  ctx.font = `800 ${w * 0.046}px Almarai, sans-serif`;
  ctx.fillText(card.fullName, textRight, baseline);

  ctx.fillStyle = GOLD_GLOW;
  ctx.font = `700 ${w * 0.022}px Almarai, sans-serif`;
  ctx.fillText(
    `${card.academicYear}  ·  مواليد ${card.birthYear}`,
    textRight,
    baseline + w * 0.038,
  );

  ctx.fillStyle = 'rgba(255,255,255,0.78)';
  ctx.font = `400 ${w * 0.021}px Almarai, sans-serif`;
  ctx.fillText(
    `محافظة ${card.governorate}`,
    textRight,
    baseline + w * 0.072,
  );

  // Footer: divider, captions, personal ID.
  const lineY = y + h - pad - h * 0.18;
  ctx.fillStyle = 'rgba(185,167,121,0.45)';
  ctx.fillRect(x + pad, lineY, w - pad * 2, 1);

  ctx.font = `400 ${w * 0.016}px Almarai, sans-serif`;
  ctx.fillStyle = 'rgba(255,255,255,0.54)';
  ctx.textAlign = 'right';
  ctx.fillText('رقم الانتساب', x + w - pad, lineY + w * 0.038);
  ctx.textAlign = 'left';
  ctx.fillText(`صدرت في ${card.issuedAtLabel}`, x + pad, lineY + w * 0.038);

  ctx.textAlign = 'right';
  ctx.fillStyle = GOLD_GLOW;
  ctx.font = `700 ${w * 0.038}px SpaceMono, monospace`;
  ctx.direction = 'ltr';
  ctx.textAlign = 'left';
  ctx.fillText(spaced(card.personalId), x + pad, y + h - pad);
  ctx.direction = 'rtl';

  ctx.restore();
}

// --------------------------------------------------------------- back face

function drawBack(ctx, card, x, y, w, h) {
  const radius = w * 0.045;
  const pad = w * 0.04;

  ctx.save();
  roundedRect(ctx, x, y, w, h, radius);
  ctx.save();
  ctx.clip();
  ctx.fillStyle = IVORY;
  ctx.fillRect(x, y, w, h);

  const watermark = w * 0.62;
  drawMark(
    ctx, GOLD, 0.13,
    x + (w - watermark) / 2,
    y + h / 2 - (watermark * 374) / 499 / 2,
    watermark,
  );
  drawMark(ctx, GOLD_DEEP, 0.07, x - w * 0.26, y + h * 0.62, w * 0.36);

  ctx.save();
  const backInset = w * 0.018;
  roundedRect(
    ctx, x + backInset, y + backInset,
    w - backInset * 2, h - backInset * 2, w * 0.032,
  );
  ctx.strokeStyle = 'rgba(185,167,121,0.28)';
  ctx.lineWidth = 0.9;
  ctx.stroke();
  ctx.restore();
  ctx.restore();

  ctx.strokeStyle = GOLD;
  ctx.lineWidth = 1.4;
  roundedRect(ctx, x, y, w, h, radius);
  ctx.stroke();

  // Details column — no QR block, so it spans the whole face.
  const colRight = x + w - pad;
  const colWidth = w - pad * 2;

  ctx.textAlign = 'right';
  ctx.fillStyle = PINE;
  ctx.font = `800 ${w * 0.026}px Almarai, sans-serif`;
  ctx.fillText('بيانات البطاقة', colRight, y + pad + w * 0.03);

  ctx.fillStyle = GOLD_DEEP;
  ctx.font = `700 ${w * 0.019}px SpaceMono, monospace`;
  ctx.direction = 'ltr';
  ctx.textAlign = 'right';
  ctx.fillText(card.personalId, colRight, y + pad + w * 0.062);
  ctx.direction = 'rtl';

  const items = [
    ['فصيلة الدم', card.bloodType],
    ['سنة الميلاد', `${card.birthYear}`],
    ['المحافظة', card.governorate],
    ['الطول', `${card.heightCm} سم`],
    ['الوزن', formatWeight(card.weightKg)],
  ];
  const cellW = colWidth / 3;
  const gridTop = y + h * 0.42;
  const rowGap = w * 0.085;

  items.forEach((item, i) => {
    const row = Math.floor(i / 3);
    const col = i % 3;
    const cellRight = colRight - col * cellW;
    const cellY = gridTop + row * rowGap;

    ctx.textAlign = 'right';
    ctx.fillStyle = INK_MUTED;
    ctx.font = `400 ${w * 0.0165}px Almarai, sans-serif`;
    ctx.fillText(item[0], cellRight, cellY);

    ctx.fillStyle = INK;
    ctx.font = `700 ${w * 0.026}px Almarai, sans-serif`;
    ctx.fillText(item[1], cellRight, cellY + w * 0.035);
  });

  // Footer strip.
  const footerY = y + h - pad - w * 0.02;
  ctx.fillStyle = 'rgba(185,167,121,0.4)';
  ctx.fillRect(colRight - colWidth, footerY - w * 0.03, colWidth, 1);

  ctx.font = `700 ${w * 0.016}px Almarai, sans-serif`;
  ctx.fillStyle = INK;
  ctx.textAlign = 'right';
  const acuityLabel = card.rightEye === card.leftEye
      ? `حدة الإبصار: ${card.rightEye}`
      : `حدة الإبصار: يمنى ${card.rightEye} · يسرى ${card.leftEye}`;
  ctx.fillText(acuityLabel, colRight, footerY);

  ctx.fillStyle = GOLD_DEEP;
  ctx.textAlign = 'left';
  ctx.fillText(card.issuedAtLabel, colRight - colWidth, footerY);

  ctx.restore();
}

// ------------------------------------------------------------------ helpers

function drawLogo(ctx, x, y, size) {
  ctx.save();
  ctx.beginPath();
  ctx.arc(x + size / 2, y + size / 2, size / 2, 0, Math.PI * 2);
  ctx.fillStyle = PINE_DEEP;
  ctx.fill();
  ctx.strokeStyle = 'rgba(185,167,121,0.75)';
  ctx.lineWidth = size * 0.045;
  ctx.stroke();
  ctx.restore();

  const crest = size * 0.66;
  drawMark(
    ctx, GOLD_GLOW, 1,
    x + (size - crest) / 2,
    y + size / 2 - (crest * 374) / 499 / 2,
    crest,
  );
}

function drawChip(ctx, x, y, w, label) {
  const height = w * 0.045;
  const padX = w * 0.026;
  ctx.save();
  ctx.font = `700 ${w * 0.017}px Almarai, sans-serif`;
  const width = ctx.measureText(label).width + padX * 2 + height * 0.7;
  ctx.fillStyle = GOLD;
  roundedRect(ctx, x, y, width, height, height / 2);
  ctx.fill();
  ctx.fillStyle = PINE_DEEP;
  ctx.textAlign = 'right';
  ctx.fillText(label, x + width - padX, y + height * 0.68);
  ctx.beginPath();
  ctx.arc(x + padX * 0.8, y + height / 2, height * 0.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function roundedRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function spaced(text) {
  return text.split('').join(' ');
}

// ------------------------------------------------------------------ exports

export function canvasToPngBlob(canvas) {
  return new Promise((resolve) => canvas.toBlob(resolve, 'image/png'));
}

/// Builds a one-page A4 PDF containing the rendered sheet.
export async function canvasToPdfBlob(canvas, title) {
  const { width, height } = canvas;
  const ctx = canvas.getContext('2d');
  const { data } = ctx.getImageData(0, 0, width, height);

  const rgb = new Uint8Array(width * height * 3);
  for (let i = 0, j = 0; i < data.length; i += 4, j += 3) {
    rgb[j] = data[i];
    rgb[j + 1] = data[i + 1];
    rgb[j + 2] = data[i + 2];
  }

  const compressed = await gzipBytes(rgb);

  const a4W = 595.28;
  const a4H = 841.89;
  const margin = 40;
  const targetW = a4W - margin * 2;
  const targetH = (targetW / width) * height;
  const targetX = margin;
  const targetY = (a4H - targetH) / 2;

  const contentStream =
    `q\n` +
    `${targetW.toFixed(2)} 0 0 ${targetH.toFixed(2)} ${targetX.toFixed(2)} ${targetY.toFixed(2)} cm\n` +
    `/Im0 Do\n` +
    `Q\n`;

  const objects = [];
  const add = (str, streamBytes) => {
    const num = objects.length + 1;
    objects.push({ num, body: str, streamBytes });
    return num;
  };

  const catalogId = add(`<< /Type /Catalog /Pages 2 0 R >>`);
  const pagesId = add(`<< /Type /Pages /Kids [3 0 R] /Count 1 >>`);
  const contentId = add(
    `<< /Length ${contentStream.length} >>\nstream\n${contentStream}endstream`,
  );
  const imageId = add(
    `<< /Type /XObject /Subtype /Image /Width ${width} /Height ${height} ` +
      `/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode ` +
      `/Length ${compressed.length} >>\nstream\n`,
    compressed,
  );
  const pageId = 3;
  objects[2] = {
    num: 3,
    body:
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${a4W} ${a4H}] ` +
      `/Contents ${contentId} 0 R ` +
      `/Resources << /XObject << /Im0 ${imageId} 0 R >> >> >>`,
  };

  let offset = 0;
  const chunks = ['%PDF-1.4\n%\xFF\xFF\xFF\xFF\n'];
  offset = byteLength(chunks[0]);

  const xref = [0];
  for (const obj of objects) {
    xref.push(offset);
    let head = `${obj.num} 0 obj\n${obj.body}\n`;
    if (obj.streamBytes) {
      head += '';
    } else if (!obj.body.endsWith('endstream')) {
      head += 'endobj\n';
    }
    chunks.push(head);
    offset += byteLength(head);

    if (obj.streamBytes) {
      chunks.push(obj.streamBytes);
      offset += obj.streamBytes.length;
      const tail = '\nendstream\nendobj\n';
      chunks.push(tail);
      offset += byteLength(tail);
    }
  }

  const startXref = offset;
  let xrefStr = `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (let i = 1; i < xref.length; i++) {
    xrefStr += `${xref[i].toString().padStart(10, '0')} 00000 n \n`;
  }
  xrefStr +=
    `trailer\n<< /Size ${objects.length + 1} /Root ${catalogId} 0 R >>\n` +
    `startxref\n${startXref}\n%%EOF\n`;
  chunks.push(xrefStr);

  return new Blob(chunks, { type: 'application/pdf' });
}

function byteLength(str) {
  return new TextEncoder().encode(str).length;
}

async function gzipBytes(bytes) {
  if (typeof CompressionStream !== 'undefined') {
    const cs = new CompressionStream('deflate');
    const stream = new Response(new Blob([bytes])).body.pipeThrough(cs);
    const ab = await new Response(stream).arrayBuffer();
    return new Uint8Array(ab);
  }
  return bytes;
}
