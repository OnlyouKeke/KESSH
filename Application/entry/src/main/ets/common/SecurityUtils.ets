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
  private static decoder: util.TextDecoder = util.TextDecoder.create();
  private static base64: util.Base64Helper = new util.Base64Helper();

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
  
  /**
   * AES-128-CBC加密，返回Base64编码的密文
   */
  static aesEncrypt(plaintext: string, key: string): string {
    try {
      // 从密钥生成128位(16字节)AES密钥
      const keyHash = SecurityUtils.sha256Hex(key);
      const keyBytes = new Uint8Array(16);
      for (let i = 0; i < 16; i++) {
        keyBytes[i] = parseInt(keyHash.substring(i * 2, i * 2 + 2), 16);
      }
      
      // 生成16字节的IV
      const iv = new Uint8Array(16);
      for (let i = 0; i < 16; i++) {
        iv[i] = Math.floor(Math.random() * 256);
      }
      
      // 创建AES-CBC加密器
      const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128');
      const symKey = symKeyGenerator.convertKeySync({ data: keyBytes });
      const cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7');
      
      // 初始化加密
      const ivParams: cryptoFramework.IvParamsSpec = {
        iv: { data: iv },
        algName: 'IvParamsSpec'
      };
      cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, ivParams);
      
      // 加密
      const plainBytes = SecurityUtils.encoder.encodeInto(plaintext);
      const encrypted = cipher.doFinalSync({ data: plainBytes });
      
      // 组装: IV(16字节) + 密文
      const result = new Uint8Array(16 + encrypted.data.length);
      result.set(iv, 0);
      result.set(encrypted.data, 16);
      
      // Base64编码
      return SecurityUtils.base64.encodeToStringSync(result);
    } catch (err) {
      const error = err as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, `AES encrypt failed: ${error.message}`);
      throw new Error(`加密失败: ${error.message}`);
    }
  }
  
  /**
   * AES-128-CBC解密
   */
  static aesDecrypt(ciphertext: string, key: string): string {
    try {
      // Base64解码
      const combined = SecurityUtils.base64.decodeSync(ciphertext);
      
      // 提取IV和密文
      const iv = combined.slice(0, 16);
      const encrypted = combined.slice(16);
      
      // 从密钥生成128位(16字节)AES密钥
      const keyHash = SecurityUtils.sha256Hex(key);
      const keyBytes = new Uint8Array(16);
      for (let i = 0; i < 16; i++) {
        keyBytes[i] = parseInt(keyHash.substring(i * 2, i * 2 + 2), 16);
      }
      
      // 创建AES-CBC解密器
      const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128');
      const symKey = symKeyGenerator.convertKeySync({ data: keyBytes });
      const cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7');
      
      // 初始化解密
      const ivParams: cryptoFramework.IvParamsSpec = {
        iv: { data: iv },
        algName: 'IvParamsSpec'
      };
      cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, ivParams);
      
      // 解密
      const decrypted = cipher.doFinalSync({ data: encrypted });
      
      // 转换为字符串
      return SecurityUtils.decoder.decodeToString(decrypted.data);
    } catch (err) {
      const error = err as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, `AES decrypt failed: ${error.message}`);
      throw new Error(`解密失败: ${error.message}`);
    }
  }
}
