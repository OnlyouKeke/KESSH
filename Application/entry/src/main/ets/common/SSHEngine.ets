import kessh from 'libkessh.so';
import hilog from '@ohos.hilog';

const LOG_DOMAIN = 0xD15B;
const LOG_TAG = 'SSHEngine';

export class SSHEngine {
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
}