import { Logger } from './Stores';
import hilog from '@ohos.hilog';

// N-API binding declaration for HarmonyOS
declare function requireNapi(moduleName: string): NativeSSHExports;

interface NativeSSHExports {
  connectPassword(host: string, port: number, username: string, password?: string): boolean;
  connectKey(host: string, port: number, username: string, privateKey: string, passphrase?: string): boolean;
  connectKey2?(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase?: string): boolean;
  execCommandPassword?(host: string, port: number, username: string, password: string, command: string): string;
  execCommandKey?(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase: string | undefined, command: string): string;
  openSessionPassword?(host: string, port: number, username: string, password: string): number; // return sessionId
  openSessionKey2?(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase?: string): number;
  termWrite?(sessionId: number, data: string): boolean;
  termRead?(sessionId: number): string;
  termClose?(sessionId: number): void;
  getVersion?(): string;
}

const HILOG_DOMAIN = 0xD15A;
const HILOG_TAG = 'NativeSSH';

let nativeBinding: NativeSSHExports | null = null;
try {
  nativeBinding = requireNapi('sshnative');
  const msg = 'Native SSH: N-API module loaded';
  Logger.log(msg);
  hilog.info(HILOG_DOMAIN, HILOG_TAG, '%{public}s', msg);
} catch (e) {
  nativeBinding = null;
  let errMsg = `${e}`;
  if (typeof e === 'object' && e !== null) {
    const errorObj = e as Error;
    if (typeof errorObj.message === 'string' && errorObj.message.length > 0) {
      errMsg = errorObj.message;
    }
  }
  Logger.log(`Native SSH: failed to load N-API module -> ${errMsg}`);
  hilog.error(HILOG_DOMAIN, HILOG_TAG, 'requireNapi failed: %{public}s', errMsg);
}

function logMissingNative(reason: string): void {
  const message = `Native SSH: native module unavailable (${reason})`;
  Logger.log(message);
  hilog.warn(HILOG_DOMAIN, HILOG_TAG, 'native module unavailable (%{public}s)', reason);
}

function logLibsshDebug(event: string, target: string, extra?: string): void {
  const suffix = extra ? `${target} ${extra}` : target;
  hilog.debug(HILOG_DOMAIN, HILOG_TAG, '[libssh] %{public}s %{public}s', event, suffix);
  Logger.log(`LibSSH: ${event} ${suffix}`);
}

function describeCommand(command: string): string {
  const trimmed = command ?? '';
  if (trimmed.length === 0) {
    return 'command=<empty>';
  }
  const maxLen = 80;
  const snippet = trimmed.length > maxLen ? `${trimmed.slice(0, maxLen)}…` : trimmed;
  return `command="${snippet}" length=${trimmed.length}`;
}

export class SSHEngine {
  static startupDiagnostic(): void {
    if (nativeBinding) {
      const version = nativeBinding.getVersion ? nativeBinding.getVersion() : '';
      const versionInfo = version && version.length > 0 ? `version=${version}` : 'version=unknown';
      logLibsshDebug('startupDiagnostic', 'libssh', versionInfo);
      Logger.log(`LibSSH startup diagnostic: ${versionInfo}`);
    } else {
      logMissingNative('startup diagnostic');
    }
  }

  static async connectPassword(host: string, port: number, username: string, password: string | undefined): Promise<boolean> {
    if (nativeBinding) {
      const target = `${username}@${host}:${port}`;
      logLibsshDebug('connectPassword:start', target, `pwProvided=${password && password.length > 0 ? 'Y' : 'N'}`);
      const ok = nativeBinding.connectPassword(host, port, username, password);
      logLibsshDebug('connectPassword:result', target, ok ? 'success' : 'failure');
      return ok ? true : false;
    }
    logMissingNative(`password auth ${username}@${host}:${port}`);
    return false;
  }

  static async connectKey(host: string, port: number, username: string, privateKey: string, passphrase?: string): Promise<boolean> {
    if (nativeBinding) {
      const target = `${username}@${host}:${port}`;
      logLibsshDebug('connectKey:start', target, `keyProvided=${privateKey && privateKey.length > 0 ? 'Y' : 'N'} passphrase=${passphrase && passphrase.length > 0 ? 'Y' : 'N'}`);
      const ok = nativeBinding.connectKey(host, port, username, privateKey, passphrase);
      logLibsshDebug('connectKey:result', target, ok ? 'success' : 'failure');
      return ok ? true : false;
    }
    logMissingNative(`key auth ${username}@${host}:${port}`);
    return false;
  }

  static async connectKey2(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase?: string): Promise<boolean> {
    if (nativeBinding && nativeBinding.connectKey2) {
      const target = `${username}@${host}:${port}`;
      logLibsshDebug('connectKey2:start', target, `priv=${privateKey && privateKey.length > 0 ? 'Y' : 'N'} pub=${publicKey && publicKey.length > 0 ? 'Y' : 'N'} passphrase=${passphrase && passphrase.length > 0 ? 'Y' : 'N'}`);
      const ok = nativeBinding.connectKey2(host, port, username, privateKey, publicKey, passphrase);
      logLibsshDebug('connectKey2:result', target, ok ? 'success' : 'failure');
      return ok ? true : false;
    }
    logMissingNative(`keypair auth ${username}@${host}:${port}`);
    return false;
  }

  static execCommandPassword(host: string, port: number, username: string, password: string, command: string): string {
    if (nativeBinding && nativeBinding.execCommandPassword) {
      const target = `${username}@${host}:${port}`;
      logLibsshDebug('execCommandPassword:start', target, describeCommand(command));
      const out = nativeBinding.execCommandPassword(host, port, username, password, command);
      logLibsshDebug('execCommandPassword:result', target, `outputLength=${out.length}`);
      return out;
    }
    logMissingNative(`exec (password) ${username}@${host}:${port}`);
    return '';
  }

  static execCommandKey(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase: string | undefined, command: string): string {
    if (nativeBinding && nativeBinding.execCommandKey) {
      const target = `${username}@${host}:${port}`;
      logLibsshDebug('execCommandKey:start', target, describeCommand(command));
      const out = nativeBinding.execCommandKey(host, port, username, privateKey, publicKey, passphrase, command);
      logLibsshDebug('execCommandKey:result', target, `outputLength=${out.length}`);
      return out;
    }
    logMissingNative(`exec (key) ${username}@${host}:${port}`);
    return '';
  }

  static openSessionPassword(host: string, port: number, username: string, password: string): number {
    if (nativeBinding && nativeBinding.openSessionPassword) {
      const target = `${username}@${host}:${port}`;
      logLibsshDebug('openSessionPassword:start', target);
      const sessionId = nativeBinding.openSessionPassword(host, port, username, password);
      logLibsshDebug('openSessionPassword:result', target, `sessionId=${sessionId}`);
      return sessionId;
    }
    logMissingNative(`open session (password) ${username}@${host}:${port}`);
    return -1;
  }

  static openSessionKey2(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase?: string): number {
    if (nativeBinding && nativeBinding.openSessionKey2) {
      const target = `${username}@${host}:${port}`;
      logLibsshDebug('openSessionKey2:start', target);
      const sessionId = nativeBinding.openSessionKey2(host, port, username, privateKey, publicKey, passphrase);
      logLibsshDebug('openSessionKey2:result', target, `sessionId=${sessionId}`);
      return sessionId;
    }
    logMissingNative(`open session (key) ${username}@${host}:${port}`);
    return -1;
  }

  static termWrite(sessionId: number, data: string): boolean {
    if (nativeBinding && nativeBinding.termWrite) {
      logLibsshDebug('termWrite', `session=${sessionId}`, `length=${data.length}`);
      return nativeBinding.termWrite(sessionId, data);
    }
    logMissingNative(`term write session=${sessionId}`);
    return false;
  }

  static termRead(sessionId: number): string {
    if (nativeBinding && nativeBinding.termRead) {
      const out = nativeBinding.termRead(sessionId);
      logLibsshDebug('termRead', `session=${sessionId}`, `length=${out.length}`);
      return out;
    }
    return '';
  }

  static termClose(sessionId: number): void {
    if (nativeBinding && nativeBinding.termClose) {
      logLibsshDebug('termClose', `session=${sessionId}`);
      nativeBinding.termClose(sessionId);
      return;
    }
    logMissingNative(`term close session=${sessionId}`);
  }
}
