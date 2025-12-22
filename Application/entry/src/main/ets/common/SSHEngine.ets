import * as kessh from 'libkessh.so';
import hilog from '@ohos.hilog';

const LOG_DOMAIN = 0xD15B;
const LOG_TAG = 'SSHEngine';

type OptionalBinding = typeof kessh & {
  testNative?: () => number;
  executeCommand?: (sid: number, cmd: string) => string;
  downloadFile?: (sid: number, path: string) => string;
  uploadFile?: (sid: number, path: string, data: string) => number;
};

const binding: OptionalBinding = kessh as OptionalBinding;

export class SSHEngine {
  static startupDiagnostic(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'startupDiagnostic invoked');
    SSHEngine.testNative();
  }

  static configureKeepalive(intervalSeconds: number, attempts: number): void {
    try {
      kessh.setKeepaliveConfig(intervalSeconds, attempts);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Keepalive config updated: %{public}d s, attempts %{public}d', intervalSeconds, attempts);
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Keepalive config failed: %{public}s', String(error));
    }
  }

  static sendKeepalive(sessionId: number): boolean {
    try {
      return kessh.sendKeepalive(sessionId);
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
      return kessh.openSession(host, port, user, pass);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'openSession failed: %{public}s', String(error));
      return -1;
    }
  }

  static closeSession(sessionId: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Closing SSH session: %{public}d', sessionId);
    try {
      kessh.closeSession(sessionId);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to close SSH session: %{public}s', String(error));
    }
  }

  static write(sessionId: number, data: string): void {
    hilog.debug(LOG_DOMAIN, LOG_TAG, 'Writing to SSH session %{public}d: %{public}s', sessionId, data);
    try {
      kessh.write(sessionId, data);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to write to SSH session: %{public}s', String(error));
    }
  }

  static read(sessionId: number): string {
    try {
      return kessh.read(sessionId);
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

  static listFiles(sessionId: number, remotePath: string): string {
    const command = `ls -la "${remotePath}" 2>&1`;
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

  static openSessionKey2(host: string, port: number, user: string, privateKey: string, publicKey: string, passphrase?: string): number {
    hilog.warn(LOG_DOMAIN, LOG_TAG, 'openSessionKey2 fallback to password session; key auth not supported in current binding');
    return SSHEngine.openSession(host, port, user, passphrase ?? '');
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
