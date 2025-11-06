import hilog from '@ohos.hilog';
import { SecurityUtils } from './SecurityUtils';

const APPLOG_DOMAIN = 0xD15A;
const APPLOG_TAG = 'AppLogger';

export type AuthType = 'password' | 'key';

export interface ConnectionDraft {
  host: string;
  port: string; // string for TextInput binding
  username: string;
  password?: string;
  privateKey?: string;
  publicKey?: string;
  passphrase?: string;
}

export interface ConnectionRecord {
  id: number;
  name: string; // e.g., user@host:port
  host: string;
  port: number;
  username: string;
  authType: AuthType;
  time: string; // display time
}

export interface ImportedKey {
  id: number;
  name: string; // display name
  content: string; // private key PEM content
  publicKey?: string; // public key (OpenSSH/PEM), optional
  passphrase?: string; // optional
  fingerprint?: string; // SHA-256 digest for display
}

export class Logger {
  private static logs: Array<string> = [];

  static log(message: string): void {
    const ts = new Date();
    const timeStr = `${ts.getHours().toString().padStart(2,'0')}:${ts.getMinutes().toString().padStart(2,'0')}:${ts.getSeconds().toString().padStart(2,'0')}`;
    Logger.logs.unshift(`[${timeStr}] ${message}`);
    hilog.debug(APPLOG_DOMAIN, APPLOG_TAG, '%{public}s', message);
  }

  static list(): Array<string> {
    return Logger.logs;
  }

  static clear(): void {
    Logger.logs = [];
  }
}

export class SettingsStore {
  static darkMode: boolean = false;
  static savePassword: boolean = false;

  static setDarkMode(v: boolean): void { SettingsStore.darkMode = v; Logger.log(`设置: 深色模式=${v ? '开' : '关'}`); }
  static setSavePassword(v: boolean): void { SettingsStore.savePassword = v; Logger.log(`设置: 保存密码=${v ? '开' : '关'}`); }
}

export class ConnectionStore {
  private static seq: number = 1;
  private static history: Array<ConnectionRecord> = [];
  static currentDraft: ConnectionDraft | null = null;

  static addFromDraft(draft: ConnectionDraft, authType: AuthType): ConnectionRecord {
    const record: ConnectionRecord = {
      id: ConnectionStore.seq++,
      name: `${draft.username}@${draft.host}:${draft.port}`,
      host: draft.host,
      port: parseInt(draft.port || '22'),
      username: draft.username,
      authType,
      time: ConnectionStore.nowLabel()
    };
    ConnectionStore.history.unshift(record);
    Logger.log(`历史: 新增 ${record.name}`);
    return record;
  }

  static list(): Array<ConnectionRecord> { return ConnectionStore.history; }

  static nowLabel(): string {
    const d = new Date();
    const hh = d.getHours().toString().padStart(2,'0');
    const mm = d.getMinutes().toString().padStart(2,'0');
    return `今天 ${hh}:${mm}`;
  }
}

export class KeyStore {
  private static seq: number = 1;
  private static keys: Array<ImportedKey> = [];

  static importKey(name: string, content: string, publicKey?: string, passphrase?: string): ImportedKey {
    const fingerprint = SecurityUtils.sha256Hex(content);
    const k: ImportedKey = { id: KeyStore.seq++, name, content, publicKey, passphrase, fingerprint };
    KeyStore.keys.unshift(k);
    Logger.log(`密钥: 导入 ${name}${fingerprint ? ` fingerprint=${fingerprint.slice(0, 12)}…` : ''}`);
    return k;
  }

  static list(): Array<ImportedKey> { return KeyStore.keys; }

  static getById(id: number): ImportedKey | null {
    for (let i = 0; i < KeyStore.keys.length; i++) {
      if (KeyStore.keys[i].id === id) { return KeyStore.keys[i]; }
    }
    return null;
  }

  static remove(id: number): void {
    KeyStore.keys = KeyStore.keys.filter(k => k.id !== id);
  }
}
