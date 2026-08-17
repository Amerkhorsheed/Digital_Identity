// Redraws the identity card on a canvas, then exports it as PNG or PDF.
//
// The proportions mirror lib/features/idcard/id_card_view.dart, so a card
// downloaded from this page matches the one the app produces.

import { encodeQr } from './qr.js';
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
const PINE_SOFT = '#DDE8E3';

/// Card width used for exports, in CSS pixels before the pixel-ratio scale.
export const CARD_WIDTH = 520;
const GAP = 24;
const MARGIN = 36;
const FOOTER = 34;

export const SHEET_WIDTH = CARD_WIDTH + MARGIN * 2;
export const SHEET_HEIGHT =
  MARGIN * 2 + CARD_WIDTH * 0.625 * 2 + GAP + FOOTER;

let logoImage = null;

export async function loadAssets() {
  await document.fonts.load('400 16px Almarai');
  await document.fonts.load('700 16px Almarai');
  await document.fonts.load('700 16px SpaceMono');
  await document.fonts.ready;

  logoImage = await new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = './assets/logo.jpg';
  });
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
    'إدارة القوى البشرية · وثيقة هوية رقمية معتمدة وموثقة بيومترياً',
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

  // Watermark and the soft gold disc, as on the app's card.
  ctx.save();
  ctx.globalAlpha = 0.12;
  ctx.fillStyle = GOLD;
  ctx.font = `800 ${h * 1.35}px Almarai, sans-serif`;
  ctx.direction = 'ltr';
  ctx.textAlign = 'left';
  ctx.fillText('A', x + w * 0.62, y + h * 1.28);
  ctx.restore();

  ctx.save();
  ctx.globalAlpha = 0.06;
  ctx.fillStyle = GOLD;
  ctx.beginPath();
  ctx.ellipse(
    x + w * 0.135, y + h * 0.15, w * 0.275, h * 0.45, 0, 0, Math.PI * 2,
  );
  ctx.fill();
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
    'رحلة حياة المنتسب · الهوية الرقمية',
    x + w - pad - logoSize - w * 0.022,
    headerY + logoSize * 0.88,
  );

  drawChip(ctx, x + pad, headerY, w, card.hasBiometric ? 'بصمة موثقة' : 'موثّقة');

  // Portrait frame.
  const photoW = w * 0.22;
  const photoH = h * 0.46;
  const photoX = x + w - pad - photoW;
  const photoY = y + h * 0.30;
  ctx.fillStyle = GOLD;
  roundedRect(ctx, photoX, photoY, photoW, photoH, w * 0.048);
  ctx.fill();
  ctx.fillStyle = PINE_SOFT;
  const inset = photoW * 0.045;
  roundedRect(
    ctx, photoX + inset, photoY + inset,
    photoW - inset * 2, photoH - inset * 2, w * 0.03,
  );
  ctx.fill();
  drawPersonGlyph(ctx, photoX + photoW / 2, photoY + photoH / 2, photoW * 0.34);

  // Name block.
  const textRight = photoX - w * 0.04;
  ctx.textAlign = 'right';
  ctx.fillStyle = '#FFFFFF';
  ctx.font = `800 ${w * 0.046}px Almarai, sans-serif`;
  ctx.fillText(card.fullName, textRight, photoY + photoH * 0.58);

  ctx.fillStyle = GOLD_GLOW;
  ctx.font = `700 ${w * 0.022}px Almarai, sans-serif`;
  ctx.fillText(
    `${card.academicYear}  ·  مواليد ${card.birthYear}`,
    textRight,
    photoY + photoH * 0.58 + w * 0.038,
  );

  ctx.fillStyle = 'rgba(255,255,255,0.78)';
  ctx.font = `400 ${w * 0.021}px Almarai, sans-serif`;
  ctx.fillText(
    `محافظة ${card.governorate}`,
    textRight,
    photoY + photoH * 0.58 + w * 0.072,
  );

  // Footer: divider, captions, personal ID.
  const lineY = y + h - pad - h * 0.18;
  ctx.fillStyle = 'rgba(185,167,121,0.45)';
  ctx.fillRect(x + pad, lineY, w - pad * 2, 1);

  ctx.font = `400 ${w * 0.016}px Almarai, sans-serif`;
  ctx.fillStyle = 'rgba(255,255,255,0.54)';
  ctx.textAlign = 'right';
  ctx.fillText('الرقم الشخصي', x + w - pad, lineY + w * 0.038);
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

  ctx.save();
  ctx.globalAlpha = 0.1;
  ctx.fillStyle = GOLD;
  ctx.font = `800 ${h * 1.3}px Almarai, sans-serif`;
  ctx.direction = 'ltr';
  ctx.textAlign = 'left';
  ctx.fillText('A', x - w * 0.12, y + h * 1.25);
  ctx.restore();
  ctx.restore();

  ctx.strokeStyle = GOLD;
  ctx.lineWidth = 1.4;
  roundedRect(ctx, x, y, w, h, radius);
  ctx.stroke();

  // QR block on the leading (right in RTL is the text side)
  const qrBoxW = w * 0.285;
  const qrBoxX = x + pad;
  const qrPad = w * 0.02;
  const qrSize = w * 0.235;
  const qrBoxH = qrSize + qrPad * 2 + w * 0.035;
  const qrBoxY = y + (h - qrBoxH) / 2;

  ctx.fillStyle = '#FFFFFF';
  roundedRect(ctx, qrBoxX, qrBoxY, qrBoxW, qrBoxH, w * 0.028);
  ctx.fill();
  ctx.strokeStyle = GOLD;
  ctx.lineWidth = 1.2;
  roundedRect(ctx, qrBoxX, qrBoxY, qrBoxW, qrBoxH, w * 0.028);
  ctx.stroke();

  drawQr(ctx, card.link, qrBoxX + (qrBoxW - qrSize) / 2, qrBoxY + qrPad, qrSize);

  ctx.fillStyle = GOLD_DEEP;
  ctx.font = `700 ${w * 0.014}px Almarai, sans-serif`;
  ctx.textAlign = 'center';
  ctx.fillText(
    'امسح للتحقق الفوري',
    qrBoxX + qrBoxW / 2,
    qrBoxY + qrPad + qrSize + w * 0.025,
  );

  // Details column.
  const colRight = x + w - pad;
  const colWidth = w - pad * 2 - qrBoxW - w * 0.035;

  ctx.textAlign = 'right';
  ctx.fillStyle = PINE;
  ctx.font = `800 ${w * 0.026}px Almarai, sans-serif`;
  ctx.fillText('بيانات الهوية الرقمية', colRight, y + pad + w * 0.03);

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
    ['البصمة البيومترية', card.biometricLabel],
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

function drawQr(ctx, text, x, y, size) {
  const qr = encodeQr(text);
  const module = size / qr.size;
  ctx.save();
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(x, y, size, size);
  ctx.fillStyle = '#000000';
  for (let r = 0; r < qr.size; r++) {
    for (let c = 0; c < qr.size; c++) {
      if (!qr.modules[r][c]) continue;
      // Overdraw by a hair so neighbouring modules never leave seams.
      ctx.fillRect(x + c * module, y + r * module, module + 0.35, module + 0.35);
    }
  }
  ctx.restore();
}

function drawLogo(ctx, x, y, size) {
  ctx.save();
  ctx.beginPath();
  ctx.arc(x + size / 2, y + size / 2, size / 2, 0, Math.PI * 2);
  ctx.fillStyle = '#FFFFFF';
  ctx.fill();
  if (logoImage) {
    ctx.clip();
    const inset = size * 0.14;
    ctx.drawImage(
      logoImage, x + inset, y + inset, size - inset * 2, size - inset * 2,
    );
  }
  ctx.restore();
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

function drawPersonGlyph(ctx, cx, cy, size) {
  ctx.save();
  ctx.fillStyle = PINE;
  ctx.beginPath();
  ctx.arc(cx, cy - size * 0.35, size * 0.32, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(cx, cy + size * 0.55, size * 0.62, Math.PI, 0);
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
