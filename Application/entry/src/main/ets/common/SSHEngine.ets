import kessh from 'libkessh.so';
import hilog from '@ohos.hilog';

const LOG_DOMAIN = 0xD15B;
const LOG_TAG = 'SSHEngine';

export class SSHEngine {
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
      const result: boolean = kessh.sendKeepalive(sessionId);
      return result;
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Keepalive send failed: %{public}s', String(error));
      return false;
    }
  }

  // 添加测试函数，不依赖libssh2
  static testNative(): number {
    hilog.info(LOG_DOMAIN, LOG_TAG, '[TEST] Calling testNative...');
    try {
      const result: number = kessh.testNative();
      hilog.info(LOG_DOMAIN, LOG_TAG, '[TEST] testNative returned: %{public}d', result);
      return result;
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, '[TEST ERROR] testNative failed: %{public}s', String(error));
      return -1;
    }
  }

  static openSession(host: string, port: number, user: string, pass: string): number {
    hilog.info(LOG_DOMAIN, LOG_TAG, '[STEP 1] START openSession call');
    hilog.info(LOG_DOMAIN, LOG_TAG, '[STEP 2] Parameters - host:%{public}s port:%{public}d user:%{public}s',
      host, port, user);
    
    // Debug: Check if kessh module is loaded
    hilog.info(LOG_DOMAIN, LOG_TAG, '[STEP 3] Checking kessh module...');
    hilog.info(LOG_DOMAIN, LOG_TAG, '[STEP 4] kessh module: %{public}s', kessh ? 'loaded' : 'undefined');
    
    if (!kessh) {
      hilog.error(LOG_DOMAIN, LOG_TAG, '[STEP 5 ERROR] kessh module is undefined - native library not loaded!');
      return -1;
    }
    
    hilog.info(LOG_DOMAIN, LOG_TAG, '[STEP 6] kessh module loaded, checking openSession function...');
    
    if (!kessh.openSession) {
      hilog.error(LOG_DOMAIN, LOG_TAG, '[STEP 7 ERROR] kessh.openSession function is undefined!');
      return -1;
    }
    
    hilog.info(LOG_DOMAIN, LOG_TAG, '[STEP 8] kessh.openSession function available, calling native code...');
    
    try {
      hilog.info(LOG_DOMAIN, LOG_TAG, '[STEP 9] Invoking kessh.openSession...');
      const result: number = kessh.openSession(host, port, user, pass);
      hilog.info(LOG_DOMAIN, LOG_TAG, '[STEP 10] Native call returned: %{public}d', result);
      return result;
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, '[STEP 11 EXCEPTION] Native call threw error: %{public}s', String(error));
      hilog.error(LOG_DOMAIN, LOG_TAG, '[STEP 12] Error name: %{public}s', error instanceof Error ? error.name : 'unknown');
      hilog.error(LOG_DOMAIN, LOG_TAG, '[STEP 13] Error message: %{public}s', error instanceof Error ? error.message : String(error));
      return -1;
    }
  }

  static closeSession(sessionId: number): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Closing SSH session: %{public}d', sessionId);
    try {
      kessh.closeSession(sessionId);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'SSH session closed successfully');
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
      const data: string = kessh.read(sessionId);
      hilog.debug(LOG_DOMAIN, LOG_TAG, 'Read from SSH session %{public}d: %{public}s', sessionId, data);
      return data;
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to read from SSH session: %{public}s', String(error));
      return '';
    }
  }

  /**
   * 执行SSH命令并返回结果
   */
  static executeCommand(sessionId: number, command: string): string {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Executing command: %{public}s', command);
    try {
      const result: string = kessh.executeCommand(sessionId, command);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Command executed successfully');
      return result;
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to execute command: %{public}s', String(error));
      return '';
    }
  }

  /**
   * 列出远程目录下的文件
   */
  static listFiles(sessionId: number, remotePath: string): string {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Listing files in: %{public}s', remotePath);
    try {
      // 使用ls -la命令获取详细信息
      const command = `ls -la "${remotePath}" 2>&1`;
      return SSHEngine.executeCommand(sessionId, command);
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to list files: %{public}s', String(error));
      return '';
    }
  }

  /**
   * 下载远程文件
   */
  static downloadFile(sessionId: number, remotePath: string): string {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Downloading file: %{public}s', remotePath);
    try {
      const content: string = kessh.downloadFile(sessionId, remotePath);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'File downloaded successfully, size: %{public}d bytes', content.length);
      return content;
    } catch (error) {
      const err = error as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to download file: %{public}s', err.message);
      throw new Error(`下载文件失败: ${err.message}`);
    }
  }

  /**
   * 上传文件到远程
   */
  static uploadFile(sessionId: number, remotePath: string, content: string): number {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Uploading file to: %{public}s, size: %{public}d bytes', remotePath, content.length);
    try {
      const bytesWritten: number = kessh.uploadFile(sessionId, remotePath, content);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'File uploaded successfully, %{public}d bytes written', bytesWritten);
      return bytesWritten;
    } catch (error) {
      const err = error as Error;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Failed to upload file: %{public}s', err.message);
      throw new Error(`上传文件失败: ${err.message}`);
    }
  }
}
