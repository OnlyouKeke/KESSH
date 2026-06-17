import * as kessh from 'libkessh.so';
import hilog from '@ohos.hilog';

const LOG_DOMAIN = 0xD15B;
const LOG_TAG = 'SSHEngine';

interface KesshNativeBinding {
  setKeepaliveConfig: (intervalSeconds: number, attempts: number) => void;
  sendKeepalive: (sessionId: number) => boolean;
  openSession: (host: string, port: number, user: string, pass: string) => number;
  openSessionAsync?: (host: string, port: number, user: string, pass: string) => Promise<number>;
  closeSession: (sessionId: number) => void;
  write: (sessionId: number, data: string) => void;
  read: (sessionId: number) => string;
  testNative?: () => number;
  executeCommand?: (sid: number, cmd: string) => string;
  downloadFile?: (sid: number, path: string) => string;
  uploadFile?: (sid: number, path: string, data: string) => number;
}

const binding: KesshNativeBinding = kessh as KesshNativeBinding;

export class SSHEngine {
  static startupDiagnostic(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'startupDiagnostic invoked');
    SSHEngine.testNative();
  }

  static configureKeepalive(intervalSeconds: number, attempts: number): void {
    try {
      binding.setKeepaliveConfig(intervalSeconds, attempts);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Keepalive config updated: %{public}d s, attempts %{public}d', intervalSeconds, attempts);
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Keepalive config failed: %{public}s', String(error));
    }
  }

  static sendKeepalive(sessionId: number): boolean {
    try {
      return binding.sendKeepalive(sessionId);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Keepalive send failed: %{public}s', String(error));
      return false;
    }
  }

  static testNative(): number {
    if (typeof binding.testNative !== 'function') {
      return 0;
    }
    try {
      return binding.testNative();
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, '[TEST ERROR] testNative failed: %{public}s', String(error));
      return -1;
    }
  }

  static openSession(host: string, port: number, user: string, pass: string): number {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Opening session host:%{public}s port:%{public}d user:%{public}s', host, port, user);
    try {
      return binding.openSession(host, port, user, pass);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'openSession failed: %{public}s', String(error));
      return -1;
    }
  }

  static async openSessionAsync(host: string, port: number, user: string, pass: string): Promise<number> {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Opening async session host:%{public}s port:%{public}d user:%{public}s', host, port, user);
    try {
      if (typeof binding.openSessionAsync === 'function') {
        return await binding.openSessionAsync(host, port, user, pass);
      }
      return binding.openSession(host, port, user, pass);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'openSessionAsync failed: %{public}s', String(error));
      return -1;
    }
  }

  static closeSession(sessionId: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Closing SSH session: %{public}d', sessionId);
    try {
      binding.closeSession(sessionId);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to close SSH session: %{public}s', String(error));
    }
  }

  static write(sessionId: number, data: string): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'Writing to SSH session %{public}d: %{public}s', sessionId, data);
    try {
      binding.write(sessionId, data);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to write to SSH session: %{public}s', String(error));
    }
  }

  static read(sessionId: number): string {
    try {
      return binding.read(sessionId);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to read from SSH session: %{public}s', String(error));
      return '';
    }
  }

  static executeCommand(sessionId: number, command: string): string {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Executing command: %{public}s', command);
    if (!binding.executeCommand) {
      return '';
    }
    try {
      return binding.executeCommand(sessionId, command);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to execute command: %{public}s', String(error));
      return '';
    }
  }

  private static shellQuoteArg(value: string): string {
    for (let i = 0; i < value.length; i++) {
      const code = value.charCodeAt(i);
      if (code === 0 || code === 10 || code === 13) {
        throw new Error('路径包含非法字符');
      }
    }
    return "'" + value.replace(/'/g, "'\\''") + "'";
  }

  static listFiles(sessionId: number, remotePath: string): string {
    const command = `ls -la -- ${SSHEngine.shellQuoteArg(remotePath)} 2>&1`;
    return SSHEngine.executeCommand(sessionId, command);
  }

  static downloadFile(sessionId: number, remotePath: string): string {
    try {
      if (binding.downloadFile) {
        return binding.downloadFile(sessionId, remotePath);
      }
      return '';
    } catch (error) {
      const err = error as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to download file: %{public}s', err.message);
      throw new Error(`Download failed: ${err.message}`);
    }
  }

  static uploadFile(sessionId: number, remotePath: string, content: string): number {
    try {
      if (binding.uploadFile) {
        return binding.uploadFile(sessionId, remotePath, content);
      }
      return content.length;
    } catch (error) {
      const err = error as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to upload file: %{public}s', err.message);
      throw new Error(`Upload failed: ${err.message}`);
    }
  }

  static openSessionPassword(host: string, port: number, user: string, pass: string): number {
    return SSHEngine.openSession(host, port, user, pass);
  }

  static async openSessionPasswordAsync(host: string, port: number, user: string, pass: string): Promise<number> {
    return await SSHEngine.openSessionAsync(host, port, user, pass);
  }

  static openSessionKey2(host: string, port: number, user: string, privateKey: string, publicKey: string, passphrase?: string): number {
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'Key authentication is not supported by current native binding');
    return -1;
  }

  static async openSessionKey2Async(host: string, port: number, user: string, privateKey: string, publicKey: string, passphrase?: string): Promise<number> {
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'Key authentication is not supported by current native binding');
    return -1;
  }

  static termWrite(sessionId: number, data: string): void {
    SSHEngine.write(sessionId, data);
  }

  static termRead(sessionId: number): string {
    return SSHEngine.read(sessionId);
  }

  static termClose(sessionId: number): void {
    SSHEngine.closeSession(sessionId);
  }
}
