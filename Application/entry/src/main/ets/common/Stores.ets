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
    return Logger.logs.slice();
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
    try {
      AppStorage.SetOrCreate(SettingsStore.DARK_MODE_KEY, SettingsStore.darkModeEnabled);
      AppStorage.SetOrCreate(SettingsStore.SAVE_PASSWORD_KEY, SettingsStore.savePasswordEnabled);
      const darkMode = AppStorage.Get<boolean>(SettingsStore.DARK_MODE_KEY);
      const savePassword = AppStorage.Get<boolean>(SettingsStore.SAVE_PASSWORD_KEY);
      if (typeof darkMode === 'boolean') {
        SettingsStore.darkModeEnabled = darkMode;
      }
      if (typeof savePassword === 'boolean') {
        SettingsStore.savePasswordEnabled = savePassword;
      }
    } catch (_) {
      // AppStorage is unavailable in unit-like contexts; keep in-memory defaults.
    }
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
    try {
      AppStorage.SetOrCreate(SettingsStore.DARK_MODE_KEY, v);
    } catch (_) {
      // ignore
    }
    Logger.log(`Setting dark_mode=${v}`);
  }

  static setSavePassword(v: boolean): void {
    SettingsStore.savePasswordEnabled = v;
    try {
      AppStorage.SetOrCreate(SettingsStore.SAVE_PASSWORD_KEY, v);
    } catch (_) {
      // ignore
    }
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

  static parsePort(portText: string): number | null {
    const value = (portText || '').trim();
    if (!/^\d+$/.test(value)) {
      return null;
    }
    const port = parseInt(value, 10);
    if (Number.isNaN(port) || port < 1 || port > 65535) {
      return null;
    }
    return port;
  }

  static validateDraft(draft: ConnectionDraft): string | null {
    if (!draft.host || draft.host.trim().length === 0) {
      return '请填写主机地址';
    }
    if (/\s/.test(draft.host.trim())) {
      return '主机地址不能包含空白字符';
    }
    if (!draft.username || draft.username.trim().length === 0) {
      return '请填写用户名';
    }
    if (ConnectionStore.parsePort(draft.port || '22') === null) {
      return '端口必须是 1-65535 的数字';
    }
    return null;
  }

  static normalizeDraft(draft: ConnectionDraft): ConnectionDraft {
    const port = ConnectionStore.parsePort(draft.port || '22') ?? 22;
    return {
      host: (draft.host || '').trim(),
      port: port.toString(),
      username: (draft.username || '').trim(),
      password: draft.password,
      privateKey: draft.privateKey,
      publicKey: draft.publicKey,
      passphrase: draft.passphrase,
      isEditing: draft.isEditing,
      editingId: draft.editingId
    };
  }

  private static cloneRecord(record: ConnectionRecord): ConnectionRecord {
    return {
      id: record.id,
      name: record.name,
      host: record.host,
      port: record.port,
      username: record.username,
      authType: record.authType,
      time: record.time
    };
  }

  private static findInternal(id: number): ConnectionRecord | null {
    for (let i = 0; i < ConnectionStore.history.length; i++) {
      if (ConnectionStore.history[i].id === id) {
        return ConnectionStore.history[i];
      }
    }
    return null;
  }

  static addFromDraft(draft: ConnectionDraft, authType: AuthType): ConnectionRecord {
    const validation = ConnectionStore.validateDraft(draft);
    if (validation) {
      throw new Error(validation);
    }
    const normalized = ConnectionStore.normalizeDraft(draft);
    const port = ConnectionStore.parsePort(normalized.port) ?? 22;

    if (normalized.isEditing && normalized.editingId !== undefined) {
      const existing = ConnectionStore.findInternal(normalized.editingId);
      if (existing) {
        existing.name = `${normalized.username}@${normalized.host}:${port}`;
        existing.host = normalized.host;
        existing.port = port;
        existing.username = normalized.username;
        existing.authType = authType;
        existing.time = ConnectionStore.nowLabel();
        Logger.log(`History: update ${existing.name}`);
        return ConnectionStore.cloneRecord(existing);
      }
    }

    const record: ConnectionRecord = {
      id: ConnectionStore.seq++,
      name: `${normalized.username}@${normalized.host}:${port}`,
      host: normalized.host,
      port,
      username: normalized.username,
      authType,
      time: ConnectionStore.nowLabel()
    };
    ConnectionStore.history.unshift(record);
    Logger.log(`History: add ${record.name}`);
    return ConnectionStore.cloneRecord(record);
  }

  static draftFromRecord(record: ConnectionRecord, password?: string): ConnectionDraft {
    const draft: ConnectionDraft = {
      host: record.host,
      port: record.port.toString(),
      username: record.username
    };
    if (record.authType === 'password') {
      draft.password = password ?? '';
    }
    return draft;
  }

  static draftForPasswordInput(record: ConnectionRecord): ConnectionDraft {
    const draft = ConnectionStore.draftFromRecord(record, '');
    draft.isEditing = true;
    draft.editingId = record.id;
    return draft;
  }

  static savePassword(record: ConnectionRecord, password: string): void {
    if (password.length > 0) {
      ConnectionStore.passwords.set(record.id, password);
    }
  }

  static getPassword(record: ConnectionRecord | null): string | null {
    if (!record) { return null; }
    return ConnectionStore.passwords.get(record.id) ?? null;
  }

  static getById(id: number): ConnectionRecord | null {
    const record = ConnectionStore.findInternal(id);
    return record ? ConnectionStore.cloneRecord(record) : null;
  }

  static list(): Array<ConnectionRecord> {
    return ConnectionStore.history.map((item: ConnectionRecord): ConnectionRecord => ConnectionStore.cloneRecord(item));
  }

  static nowLabel(): string {
    const d = new Date();
    const hh = d.getHours().toString().padStart(2, '0');
    const mm = d.getMinutes().toString().padStart(2, '0');
    return `Today ${hh}:${mm}`;
  }
}

export interface Snippet {
  id: number;
  title: string;
  command: string;
}

export class SnippetStore {
  private static seq: number = 3;
  private static snippets: Array<Snippet> = [
    { id: 0, title: 'List files', command: 'ls -la' },
    { id: 1, title: 'Check disk', command: 'df -h' },
    { id: 2, title: 'Check memory', command: 'free -m' }
  ];

  static list(): Array<Snippet> {
    return SnippetStore.snippets.map((item: Snippet): Snippet => {
      return { id: item.id, title: item.title, command: item.command };
    });
  }

  static add(title: string, command: string): void {
    SnippetStore.snippets.push({ id: SnippetStore.seq++, title, command });
  }

  static remove(id: number): void {
    SnippetStore.snippets = SnippetStore.snippets.filter(s => s.id !== id);
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

  static list(): Array<ImportedKey> {
    return KeyStore.keys.map((item: ImportedKey): ImportedKey => {
      return {
        id: item.id,
        name: item.name,
        content: item.content,
        publicKey: item.publicKey,
        passphrase: item.passphrase,
        fingerprint: item.fingerprint
      };
    });
  }

  static getById(id: number): ImportedKey | null {
    for (let i = 0; i < KeyStore.keys.length; i++) {
      if (KeyStore.keys[i].id === id) {
        return {
          id: KeyStore.keys[i].id,
          name: KeyStore.keys[i].name,
          content: KeyStore.keys[i].content,
          publicKey: KeyStore.keys[i].publicKey,
          passphrase: KeyStore.keys[i].passphrase,
          fingerprint: KeyStore.keys[i].fingerprint
        };
      }
    }
    return null;
  }

  static remove(id: number): void {
    KeyStore.keys = KeyStore.keys.filter(k => k.id !== id);
  }
}
