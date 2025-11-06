import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';
import hilog from '@ohos.hilog';

const LOG_DOMAIN = 0xD15A;
const LOG_TAG = 'SecurityUtils';

function toHex(bytes: Uint8Array): string {
  let hex = '';
  for (let i = 0; i < bytes.length; i++) {
    hex += bytes[i].toString(16).padStart(2, '0');
  }
  return hex;
}

function fallbackHash(data: string): string {
  let h1 = 0x811c9dc5;
  let h2 = 0x01000193;
  for (let i = 0; i < data.length; i++) {
    const c = data.charCodeAt(i);
    h1 = (h1 ^ c) * 0x01000193;
    h1 = h1 >>> 0;
    h2 = ((h2 << 5) - h2) ^ c;
    h2 = h2 >>> 0;
  }
  return `${h1.toString(16).padStart(8, '0')}${h2.toString(16).padStart(8, '0')}`;
}

export class SecurityUtils {
  private static encoder: util.TextEncoder = util.TextEncoder.create();

  static sha256Hex(data: string): string {
    if (!data) {
      return '';
    }
    try {
      const md = cryptoFramework.createMd('SHA256');
      const encoded: Uint8Array = SecurityUtils.encoder.encodeInto(data);
      const input: cryptoFramework.DataBlob = { data: encoded };
      md.updateSync(input);
      const result: cryptoFramework.DataBlob = md.digestSync();
      return toHex(result.data);
    } catch {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'sha256 failed, fallback used');
      return fallbackHash(data);
    }
  }
}
