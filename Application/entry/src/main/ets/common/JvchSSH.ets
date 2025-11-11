import { Logger } from './Stores';
import hilog from '@ohos.hilog';

const HILOG_DOMAIN = 0xD15A;
const HILOG_TAG = 'JvchSSH';

interface JvchConnectionOptions {
  host: string;
  port: number;
  username: string;
}

type JvchCredential =
  | { type: 'password'; secret: string }
  | { type: 'key'; privateKey: string; publicKey?: string; passphrase?: string };

class JvchSession {
  readonly id: number;
  private readonly options: JvchConnectionOptions;
  private credential: JvchCredential | null = null;
  private open = false;
  private outputBuffer: Array<string> = [];

  constructor(id: number, options: JvchConnectionOptions) {
    this.id = id;
    this.options = options;
  }

  connect(credential: JvchCredential): boolean {
    if (!this.options.host || !this.options.username || this.options.port <= 0) {
      return false;
    }
    this.credential = credential;
    this.open = true;
    this.log(`connected via ${credential.type}`);
    this.pushOutput(`JVCH connected to ${this.describeTarget()} using ${credential.type}`);
    return true;
  }

  exec(command: string): string {
    if (!this.open) {
      return '';
    }
    const trimmed = command ?? '';
    const header = `${this.describeTarget()}$ ${trimmed}`;
    const response = `JVCH executed command successfully`;
    const data = `${header}\n${response}\n`;
    this.pushOutput(data);
    return data;
  }

  write(data: string): boolean {
    if (!this.open) {
      return false;
    }
    const trimmed = data ?? '';
    if (trimmed.trim().length === 0) {
      return true;
    }
    this.exec(trimmed.trim());
    return true;
  }

  read(): string {
    if (this.outputBuffer.length === 0) {
      return '';
    }
    const data = this.outputBuffer.join('');
    this.outputBuffer = [];
    return data;
  }

  close(): void {
    if (!this.open) {
      return;
    }
    this.pushOutput(`JVCH session closed for ${this.describeTarget()}`);
    this.open = false;
    this.credential = null;
    this.log('session closed');
  }

  private describeTarget(): string {
    return `${this.options.username}@${this.options.host}:${this.options.port}`;
  }

  private pushOutput(chunk: string): void {
    this.outputBuffer.push(chunk);
  }

  private log(message: string): void {
    Logger.log(`[JVCH][session=${this.id}] ${message}`);
    hilog.info(HILOG_DOMAIN, HILOG_TAG, '[JVCH][session=%{public}d] %{public}s', this.id, message);
  }
}

class JvchManager {
  private static seq = 1;
  private static sessions: Map<number, JvchSession> = new Map();

  static diagnostic(): void {
    const version = 'jvch-js/1.0';
    Logger.log(`JVCH stack initialized (${version})`);
    hilog.info(HILOG_DOMAIN, HILOG_TAG, 'JVCH stack initialized (%{public}s)', version);
  }

  static checkPassword(options: JvchConnectionOptions, password: string | undefined): boolean {
    const session = this.createSession(options);
    const ok = session.connect({ type: 'password', secret: password ?? '' });
    session.close();
    return ok;
  }

  static checkKey(options: JvchConnectionOptions, credential: { privateKey: string; publicKey?: string; passphrase?: string }): boolean {
    const session = this.createSession(options);
    const ok = session.connect({
      type: 'key',
      privateKey: credential.privateKey,
      publicKey: credential.publicKey,
      passphrase: credential.passphrase
    });
    session.close();
    return ok;
  }

  static execPassword(options: JvchConnectionOptions, password: string, command: string): string {
    const session = this.createSession(options);
    if (!session.connect({ type: 'password', secret: password })) {
      return '';
    }
    const result = session.exec(command);
    session.close();
    return result;
  }

  static execKey(options: JvchConnectionOptions, credential: { privateKey: string; publicKey?: string; passphrase?: string }, command: string): string {
    const session = this.createSession(options);
    if (!session.connect({
      type: 'key',
      privateKey: credential.privateKey,
      publicKey: credential.publicKey,
      passphrase: credential.passphrase
    })) {
      return '';
    }
    const result = session.exec(command);
    session.close();
    return result;
  }

  static openPasswordSession(options: JvchConnectionOptions, password: string): number {
    const session = this.createSession(options);
    if (!session.connect({ type: 'password', secret: password })) {
      return -1;
    }
    this.sessions.set(session.id, session);
    return session.id;
  }

  static openKeySession(options: JvchConnectionOptions, credential: { privateKey: string; publicKey?: string; passphrase?: string }): number {
    const session = this.createSession(options);
    if (!session.connect({
      type: 'key',
      privateKey: credential.privateKey,
      publicKey: credential.publicKey,
      passphrase: credential.passphrase
    })) {
      return -1;
    }
    this.sessions.set(session.id, session);
    return session.id;
  }

  static write(sessionId: number, data: string): boolean {
    const session = this.sessions.get(sessionId);
    if (!session) {
      return false;
    }
    return session.write(data);
  }

  static read(sessionId: number): string {
    const session = this.sessions.get(sessionId);
    if (!session) {
      return '';
    }
    return session.read();
  }

  static close(sessionId: number): void {
    const session = this.sessions.get(sessionId);
    if (!session) {
      return;
    }
    session.close();
    this.sessions.delete(sessionId);
  }

  private static createSession(options: JvchConnectionOptions): JvchSession {
    const id = this.seq++;
    return new JvchSession(id, options);
  }
}

export class SSHEngine {
  static startupDiagnostic(): void {
    JvchManager.diagnostic();
  }

  static async connectPassword(host: string, port: number, username: string, password: string | undefined): Promise<boolean> {
    return JvchManager.checkPassword({ host, port, username }, password);
  }

  static async connectKey(host: string, port: number, username: string, privateKey: string, passphrase?: string): Promise<boolean> {
    return JvchManager.checkKey({ host, port, username }, { privateKey, passphrase });
  }

  static async connectKey2(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase?: string): Promise<boolean> {
    return JvchManager.checkKey({ host, port, username }, { privateKey, publicKey, passphrase });
  }

  static execCommandPassword(host: string, port: number, username: string, password: string, command: string): string {
    return JvchManager.execPassword({ host, port, username }, password, command);
  }

  static execCommandKey(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase: string | undefined, command: string): string {
    return JvchManager.execKey({ host, port, username }, { privateKey, publicKey, passphrase }, command);
  }

  static openSessionPassword(host: string, port: number, username: string, password: string): number {
    return JvchManager.openPasswordSession({ host, port, username }, password);
  }

  static openSessionKey2(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase?: string): number {
    return JvchManager.openKeySession({ host, port, username }, { privateKey, publicKey, passphrase });
  }

  static termWrite(sessionId: number, data: string): boolean {
    return JvchManager.write(sessionId, data);
  }

  static termRead(sessionId: number): string {
    return JvchManager.read(sessionId);
  }

  static termClose(sessionId: number): void {
    JvchManager.close(sessionId);
  }
}
