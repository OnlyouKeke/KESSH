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
  isEditing?: boolean;
  editingId?: number;
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

  static info(message: string): void {
    Logger.log(message);
  }

  static warn(message: string): void {
    Logger.log(`[WARN] ${message}`);
  }

  static error(message: string): void {
    Logger.log(`[ERROR] ${message}`);
  }

  static log(message: string): void {
    const ts = new Date();
    const timeStr = `${ts.getHours().toString().padStart(2, '0')}:${ts.getMinutes().toString().padStart(2, '0')}:${ts.getSeconds().toString().padStart(2, '0')}`;
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
  static readonly DARK_MODE_KEY = 'lynx_dark_mode';
  static readonly SAVE_PASSWORD_KEY = 'lynx_save_password';
  static readonly SESSION_KEEPALIVE_INTERVAL_KEY = 'lynx_session_keepalive_interval';
  static readonly SESSION_KEEPALIVE_ATTEMPTS_KEY = 'lynx_session_keepalive_attempts';
  static readonly TERMINAL_FONT_FAMILY_KEY = 'lynx_terminal_font_family';
  static readonly TERMINAL_FONT_SIZE_KEY = 'lynx_terminal_font_size';

  private static darkModeEnabled: boolean = false;
  private static savePasswordEnabled: boolean = false;
  private static keepaliveInterval: number = 60;
  private static keepaliveAttempts: number = 3;
  private static terminalFontFamilyValue: string = 'system';
  private static terminalFontSizeValue: number = 14;

  static ensureInitialized(): void {
    // No-op for now; values are kept in-memory.
  }

  static get darkMode(): boolean {
    return SettingsStore.darkModeEnabled;
  }
  static get savePassword(): boolean {
    return SettingsStore.savePasswordEnabled;
  }
  static get sessionKeepaliveInterval(): number {
    return SettingsStore.keepaliveInterval;
  }
  static get sessionKeepaliveAttempts(): number {
    return SettingsStore.keepaliveAttempts;
  }
  static get terminalFontFamily(): string {
    return SettingsStore.terminalFontFamilyValue;
  }
  static get terminalFontSize(): number {
    return SettingsStore.terminalFontSizeValue;
  }

  static setDarkMode(v: boolean): void {
    SettingsStore.darkModeEnabled = v;
    Logger.log(`Setting dark_mode=${v}`);
  }

  static setSavePassword(v: boolean): void {
    SettingsStore.savePasswordEnabled = v;
    Logger.log(`Setting save_password=${v}`);
  }

  static async setSessionKeepaliveInterval(v: number): Promise<void> {
    SettingsStore.keepaliveInterval = v;
    Logger.info(`Keepalive interval set to ${v}s`);
  }

  static async setSessionKeepaliveAttempts(v: number): Promise<void> {
    SettingsStore.keepaliveAttempts = v;
    Logger.info(`Keepalive attempts set to ${v}`);
  }

  static async setTerminalFontFamily(family: string): Promise<void> {
    SettingsStore.terminalFontFamilyValue = family;
    Logger.info(`Terminal font family=${family}`);
  }

  static async setTerminalFontSize(size: number): Promise<void> {
    SettingsStore.terminalFontSizeValue = size;
    Logger.info(`Terminal font size=${size}`);
  }
}

export class ConnectionStore {
  private static seq: number = 1;
  private static history: Array<ConnectionRecord> = [];
  private static passwords: Map<number, string> = new Map();
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
    Logger.log(`History: add ${record.name}`);
    return record;
  }

  static savePassword(record: ConnectionRecord, password: string): void {
    ConnectionStore.passwords.set(record.id, password);
  }

  static getPassword(record: ConnectionRecord | null): string | null {
    if (!record) { return null; }
    return ConnectionStore.passwords.get(record.id) ?? null;
  }

  static list(): Array<ConnectionRecord> { return ConnectionStore.history; }

  static nowLabel(): string {
    const d = new Date();
    const hh = d.getHours().toString().padStart(2, '0');
    const mm = d.getMinutes().toString().padStart(2, '0');
    return `Today ${hh}:${mm}`;
  }
}

export class KeyStore {
  private static seq: number = 1;
  private static keys: Array<ImportedKey> = [];

  static importKey(name: string, content: string, publicKey?: string, passphrase?: string): ImportedKey {
    const fingerprint = SecurityUtils.sha256Hex(content);
    const k: ImportedKey = { id: KeyStore.seq++, name, content, publicKey, passphrase, fingerprint };
    KeyStore.keys.unshift(k);
    Logger.log(`Key import ${name}${fingerprint ? ` fingerprint=${fingerprint.slice(0, 12)}…` : ''}`);
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
