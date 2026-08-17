// Decodes the card payload carried in the URL fragment.
//
// Mirrors lib/services/card_link.dart exactly: the frame is
// [version][flags][crc16-hi][crc16-lo][body], base64url encoded, where body is
// a compact JSON map, gzipped when that saved space.
//
// The payload lives in the fragment (after `#`), which HTTP never transmits —
// so the identity data is decoded here in the browser and never reaches any
// server.

export const FORMAT_VERSION = 2;

const ACADEMIC_YEARS = [
  'إجازة جامعية (بكالوريوس)',
  'دبلوم معهد تقاني',
  'ماجستير',
  'دكتوراه',
  'الشهادة الثانوية',
  'أخرى',
];

const BLOOD_TYPES = ['A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−'];

// يجب أن يطابق ترتيب VisualAcuity في lib/models/applicant.dart — الرمز يخزّن
// ترتيب القيمة لا نصّها، فأي إدراج في الوسط يُفسد البطاقات المطبوعة.
const ACUITIES = [
  '20/10', '20/13', '20/16', '20/20', '20/25', '20/30',
  '20/40', '20/50', '20/70', '20/100', '20/200', 'أسوأ من 20/200',
];

const CORRECTIONS = ['بدون', 'نظارات', 'عدسات لاصقة'];

const MONTHS = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

export class CardError extends Error {}

export async function decodeCard(fragment) {
  const raw = (fragment || '').replace(/^#/, '').trim();
  if (!raw) throw new CardError('لا يوجد رمز بطاقة في الرابط.');

  let framed;
  try {
    framed = base64UrlDecode(raw);
  } catch {
    throw new CardError('الرمز غير صالح أو مقطوع.');
  }
  if (framed.length < 5) throw new CardError('الرمز غير مكتمل.');

  if (framed[0] > FORMAT_VERSION) {
    throw new CardError('هذه البطاقة صادرة بإصدار أحدث. حدّث الصفحة.');
  }

  const flags = framed[1];
  const crc = (framed[2] << 8) | framed[3];
  const body = framed.subarray(4);
  if (crc16(body) !== crc) {
    throw new CardError('الرمز تالف أو قُرئ خطأ. أعد المسح.');
  }

  const json = (flags & 1) !== 0 ? await gunzip(body) : body;

  let map;
  try {
    map = JSON.parse(new TextDecoder().decode(json));
  } catch {
    throw new CardError('تعذّر قراءة محتوى الرمز.');
  }

  return toCard(map);
}

function toCard(map) {
  const issuedAt = new Date((map.t || 0) * 1000);
  const pick = (list, index) =>
    list[Number.isInteger(index) && index >= 0 && index < list.length ? index : 0];

  const governorate = map.g || '';
  const city = map.c || '';

  return {
    personalId: map.i || '',
    fullName: (map.n || '').trim(),
    academicYear: pick(ACADEMIC_YEARS, map.y),
    degree: map.d || '',
    governorate,
    city,
    placeLabel: city && city !== governorate ? `${city}، ${governorate}` : governorate,
    heightCm: map.h || 0,
    weightKg: (map.w || 0) / 10,
    bloodType: pick(BLOOD_TYPES, map.b),
    rightEye: pick(ACUITIES, map.r),
    leftEye: pick(ACUITIES, map.l),
    correction: pick(CORRECTIONS, map.x),
    visionDistanceCm: typeof map.m === 'number' ? map.m : null,
    visionSource:
      typeof map.m === 'number' ? `فحص تفاعلي · ${map.m} سم` : 'إدخال يدوي',
    issuedAt,
    issuedAtLabel: formatDate(issuedAt),
  };
}

export function formatDate(date) {
  return `${date.getUTCDate()} ${MONTHS[date.getUTCMonth()]} ${date.getUTCFullYear()}`;
}

export function formatWeight(kg) {
  return Number.isInteger(kg) ? `${kg} كجم` : `${kg.toFixed(1)} كجم`;
}

// ------------------------------------------------------------------ plumbing

function base64UrlDecode(text) {
  const padded = text.replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(padded + '='.repeat((4 - (padded.length % 4)) % 4));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function gunzip(bytes) {
  if (typeof DecompressionStream === 'undefined') {
    throw new CardError('متصفحك قديم ولا يدعم فك الضغط. جرّب متصفحًا أحدث.');
  }
  const stream = new Blob([bytes]).stream().pipeThrough(
    new DecompressionStream('gzip'),
  );
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

/// CRC-16/CCITT-FALSE, identical to the Dart side.
function crc16(bytes) {
  let crc = 0xffff;
  for (const byte of bytes) {
    crc ^= byte << 8;
    for (let i = 0; i < 8; i++) {
      crc = (crc & 0x8000) !== 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xffff;
    }
  }
  return crc;
}
