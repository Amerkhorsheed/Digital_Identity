// Decodes the card payload carried in the URL fragment.
//
// Mirrors lib/services/card_link.dart exactly: the frame is
// [version][flags][crc16-hi][crc16-lo][body], base64url encoded, where body is
// a compact JSON map, gzipped when that saved space.
//
// The payload lives in the fragment (after `#`), which HTTP never transmits —
// so the identity data is decoded here in the browser and never reaches any
// server.

export const FORMAT_VERSION = 3;

const ACADEMIC_YEARS = [
  'إجازة جامعية (بكالوريوس)',
  'دبلوم معهد تقاني',
  'ماجستير',
  'دكتوراه',
  'الشهادة الثانوية',
  'أخرى',
];

const BLOOD_TYPES = ['A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−'];

const ACUITIES = [
  '20/10', '20/13', '20/16', '20/20', '20/25', '20/30',
  '20/40', '20/50', '20/70', '20/100', '20/200', 'أسوأ من 20/200',
];

const BIOMETRIC_METHODS = [
  { code: 'HW-FP', label: 'بصمة إصبع — مستشعر الجهاز', shortLabel: 'بصمة إصبع', isHw: true },
  { code: 'HW-FACE', label: 'تعرّف على الوجه — مستشعر الجهاز', shortLabel: 'تعرّف على الوجه', isHw: true },
  { code: 'HW-IRIS', label: 'بصمة قزحية — مستشعر الجهاز', shortLabel: 'بصمة قزحية', isHw: true },
  { code: 'HW-BIO', label: 'قياس حيوي موثّق من الجهاز', shortLabel: 'قياس حيوي', isHw: true },
  { code: 'TP-FP', label: 'التقاط بصمة — لوحة اللمس', shortLabel: 'التقاط لمسي', isHw: false },
];

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
  const birthYear = map.a || 2001;

  let biometric = null;
  if (typeof map.pb === 'string') {
    const parts = map.pb.split('.');
    const methodIdx = parseInt(parts[0], 10);
    if (!isNaN(methodIdx) && methodIdx >= 0 && methodIdx < BIOMETRIC_METHODS.length) {
      const method = BIOMETRIC_METHODS[methodIdx];
      const age = parseInt(parts[1], 10) || 0;
      const quality = parseInt(parts[2], 10);
      const hash = parts[3] || '';
      const shortHash =
        hash && hash.length >= 12
          ? `${hash.slice(0, 4)}-${hash.slice(4, 8)}-${hash.slice(8, 12)}`.toUpperCase()
          : hash ? hash.toUpperCase() : null;

      let provenanceLabel = method.shortLabel;
      if (quality >= 0) provenanceLabel += ` · جودة ${quality}٪`;
      if (shortHash) provenanceLabel += ` · ${shortHash}`;

      biometric = {
        method,
        age,
        quality: quality >= 0 ? quality : null,
        hash,
        shortHash,
        isHardwareMatch: method.isHw,
        verificationLabel: method.isHw ? 'موثقة' : 'مُلتقطة',
        provenanceLabel,
      };
    }
  }

  const hasBiometric = biometric !== null || (map.p !== undefined && map.p !== 0);
  const biometricLabel = biometric
    ? biometric.provenanceLabel
    : (hasBiometric ? 'موثقة بيومترياً' : 'غير مسجلة');

  return {
    personalId: map.i || '',
    fullName: (map.n || '').trim(),
    birthYear,
    academicYear: pick(ACADEMIC_YEARS, map.y),
    governorate,
    placeLabel: governorate,
    heightCm: map.h || 0,
    weightKg: (map.w || 0) / 10,
    bloodType: pick(BLOOD_TYPES, map.b),
    rightEye: pick(ACUITIES, map.r),
    leftEye: pick(ACUITIES, map.l),
    biometric,
    hasBiometric,
    biometricLabel,
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
  let s = text.replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4 !== 0) s += '=';
  const bin = atob(s);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

function crc16(bytes) {
  let crc = 0xffff;
  for (let i = 0; i < bytes.length; i++) {
    crc ^= bytes[i] << 8;
    for (let bit = 0; bit < 8; bit++) {
      crc = (crc & 0x8000) !== 0 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
    }
  }
  return crc;
}

async function gunzip(bytes) {
  if (typeof DecompressionStream === 'undefined') {
    throw new CardError('المتصفح لا يدعم فك الضغط التلقائي.');
  }
  const ds = new DecompressionStream('gzip');
  const stream = new Response(new Blob([bytes])).body.pipeThrough(ds);
  const ab = await new Response(stream).arrayBuffer();
  return new Uint8Array(ab);
}
