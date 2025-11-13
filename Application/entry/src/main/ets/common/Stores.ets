import hilog from '@ohos.hilog';
import { SecurityUtils } from './SecurityUtils';
import { AccountManager } from './AccountManager';
import preferences from '@ohos.data.preferences';
import type { Context } from '@kit.AbilityKit';

const APPLOG_DOMAIN = 0xD15A;
const APPLOG_TAG = 'AppLogger';
const PREF_NAME = 'kessh_data';
const KEY_CONNECTIONS = 'connections';
const KEY_SEQ = 'connection_seq';

export type AuthType = 'password' | 'key';
export type ConnectionStatus = 'success' | 'failed' | 'timeout' | 'refused' | 'auth_failed';
export type LogLevel = 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';

export interface ConnectionDraft {
  host: string;
  port: string; // string for TextInput binding
  username: string;
  password?: string;
  privateKey?: string;
  publicKey?: string;
  passphrase?: string;
  isEditing?: boolean; // 是否为编辑模式
  editingId?: number; // 编辑的记录ID
}

export interface ConnectionRecord {
  id: number;
  name: string; // e.g., user@host:port
  host: string;
  port: number;
  username: string;
  authType: AuthType;
  time: string; // display time
  timestamp: number; // Unix timestamp for sorting
  status?: ConnectionStatus; // 连接结果状态
  errorMsg?: string; // 错误消息
  duration?: number; // 连接耗时(ms)
  encryptedPassword?: string; // 加密后的密码（Base64）
}

export interface ImportedKey {
  id: number;
  name: string; // display name
  content: string; // private key PEM content
  publicKey?: string; // public key (OpenSSH/PEM), optional
  passphrase?: string; // optional
  fingerprint?: string; // SHA-256 digest for display
}

export interface LogEntry {
  id: number;
  timestamp: number;
  level: LogLevel;
  message: string;
  timeStr: string;
}

export class Logger {
  private static logs: Array<LogEntry> = [];
  private static seq: number = 1;
  private static readonly MAX_LOGS = 500; // 最多保存500条日志

  static log(message: string, level: LogLevel = 'INFO'): void {
    const ts = new Date();
    const timeStr = `${ts.getHours().toString().padStart(2,'0')}:${ts.getMinutes().toString().padStart(2,'0')}:${ts.getSeconds().toString().padStart(2,'0')}.${ts.getMilliseconds().toString().padStart(3,'0')}`;
    
    const entry: LogEntry = {
      id: Logger.seq++,
      timestamp: ts.getTime(),
      level,
      message,
      timeStr
    };
    
    Logger.logs.unshift(entry);
    
    // 限制日志数量
    if (Logger.logs.length > Logger.MAX_LOGS) {
      Logger.logs = Logger.logs.slice(0, Logger.MAX_LOGS);
    }
    
    // 输出到hilog
    switch (level) {
      case 'DEBUG':
        hilog.debug(APPLOG_DOMAIN, APPLOG_TAG, '%{public}s', message);
        break;
      case 'INFO':
        hilog.info(APPLOG_DOMAIN, APPLOG_TAG, '%{public}s', message);
        break;
      case 'WARN':
        hilog.warn(APPLOG_DOMAIN, APPLOG_TAG, '%{public}s', message);
        break;
      case 'ERROR':
        hilog.error(APPLOG_DOMAIN, APPLOG_TAG, '%{public}s', message);
        break;
    }
  }
  
  static debug(message: string): void { Logger.log(message, 'DEBUG'); }
  static info(message: string): void { Logger.log(message, 'INFO'); }
  static warn(message: string): void { Logger.log(message, 'WARN'); }
  static error(message: string): void { Logger.log(message, 'ERROR'); }

  static list(level?: LogLevel): Array<LogEntry> {
    if (level) {
      return Logger.logs.filter(entry => entry.level === level);
    }
    return Logger.logs;
  }

  static clear(): void {
    Logger.logs = [];
    Logger.seq = 1;
    Logger.info('Logger: 日志已清空');
  }
  
  static export(): string {
    let output = `=== SSH Client Logs ===\n`;
    output += `Generated at: ${new Date().toLocaleString()}\n`;
    output += `Total entries: ${Logger.logs.length}\n`;
    output += `\n`;
    
    const reversedLogs = [...Logger.logs].reverse();
    for (const entry of reversedLogs) {
      output += `[${entry.timeStr}] [${entry.level}] ${entry.message}\n`;
    }
    
    return output;
  }
}

export class SettingsStore {
  static darkMode: boolean = false;
  static savePassword: boolean = false;

  static setDarkMode(v: boolean): void { 
    SettingsStore.darkMode = v; 
    Logger.info(`设置: 深色模式=${v ? '开' : '关'}`);
  }
  
  static setSavePassword(v: boolean): void { 
    SettingsStore.savePassword = v; 
    Logger.info(`设置: 保存密码=${v ? '开' : '关'}`);
  }
}

// 导入结果类型
export interface ImportResult {
  success: number;
  failed: number;
  total: number;
}

export class ConnectionStore {
  private static seq: number = 1;
  private static history: Array<ConnectionRecord> = [];
  static currentDraft: ConnectionDraft | null = null;
  private static prefStore: preferences.Preferences | null = null;
  private static initialized: boolean = false;

  // 初始化数据库
  /**
   * 使用AES加密密码
   */
  private static encryptPassword(password: string): string {
    try {
      // 使用用户ID作为加密密钥
      const encryptionKey = AccountManager.getEncryptionKey();
      return SecurityUtils.aesEncrypt(password, encryptionKey);
    } catch (err) {
      Logger.error(`密码加密失败: ${err}`);
      return '';
    }
  }
  
  /**
   * 解密密码
   */
  private static decryptPassword(encrypted: string): string {
    try {
      // 使用用户ID作为解密密钥
      const encryptionKey = AccountManager.getEncryptionKey();
      return SecurityUtils.aesDecrypt(encrypted, encryptionKey);
    } catch (err) {
      Logger.error(`密码解密失败: ${err}`);
      return '';
    }
  }

  static async init(context: Context): Promise<void> {
    if (ConnectionStore.initialized) return;
    
    try {
      ConnectionStore.prefStore = await preferences.getPreferences(context, PREF_NAME);
      
      // 读取序列号
      const seqValue = await ConnectionStore.prefStore.get(KEY_SEQ, 1);
      ConnectionStore.seq = seqValue as number;
      
      // 读取历史记录
      const historyJson = await ConnectionStore.prefStore.get(KEY_CONNECTIONS, '[]');
      ConnectionStore.history = JSON.parse(historyJson as string);
      
      ConnectionStore.initialized = true;
      Logger.info(`ConnectionStore: 初始化完成, 加载${ConnectionStore.history.length}条记录`);
    } catch (err) {
      Logger.error(`ConnectionStore: 初始化失败 ${err}`);
    }
  }
  
  // 保存到数据库
  private static async save(): Promise<void> {
    if (!ConnectionStore.prefStore) return;
    
    try {
      await ConnectionStore.prefStore.put(KEY_SEQ, ConnectionStore.seq);
      await ConnectionStore.prefStore.put(KEY_CONNECTIONS, JSON.stringify(ConnectionStore.history));
      await ConnectionStore.prefStore.flush();
    } catch (err) {
      Logger.error(`ConnectionStore: 保存失败 ${err}`);
    }
  }

  static addFromDraft(draft: ConnectionDraft, authType: AuthType, status?: ConnectionStatus, errorMsg?: string, duration?: number, savePassword: boolean = false): ConnectionRecord {
    const ts = new Date();
    
    // 检查是否已存在相同的主机+用户名组合
    const existingIndex = ConnectionStore.history.findIndex(r => 
      r.host === draft.host && 
      r.port === parseInt(draft.port || '22') && 
      r.username === draft.username
    );
    
    const record: ConnectionRecord = {
      id: existingIndex >= 0 ? ConnectionStore.history[existingIndex].id : ConnectionStore.seq++,
      name: `${draft.username}@${draft.host}:${draft.port}`,
      host: draft.host,
      port: parseInt(draft.port || '22'),
      username: draft.username,
      authType,
      time: ConnectionStore.formatTime(ts),
      timestamp: ts.getTime(),
      status,
      errorMsg,
      duration
    };
    
    // 如果需要保存密码且密码存在，则加密保存
    if (savePassword && draft.password) {
      record.encryptedPassword = ConnectionStore.encryptPassword(draft.password);
      Logger.info(`历史: 已加密保存密码`);
    }
    
    // 如果存在相同配置，删除旧的
    if (existingIndex >= 0) {
      ConnectionStore.history.splice(existingIndex, 1);
      Logger.info(`历史: 更新已存在的主机 ${record.name}`);
    }
    
    // 添加到列表开头
    ConnectionStore.history.unshift(record);
    
    // 限制历史记录数量
    if (ConnectionStore.history.length > 100) {
      ConnectionStore.history = ConnectionStore.history.slice(0, 100);
    }
    
    const statusText = status === 'success' ? '成功' : status === 'failed' ? '失败' : status === 'timeout' ? '超时' : status === 'refused' ? '被拒' : status === 'auth_failed' ? '认证失败' : '未知';
    Logger.info(`历史: 新增 ${record.name} [状态:${statusText}${duration ? `, 耗时:${duration}ms` : ''}]`);
    
    // 保存到数据库
    ConnectionStore.save();
    
    return record;
  }
  
  static updateStatus(id: number, status: ConnectionStatus, errorMsg?: string, duration?: number): void {
    const record = ConnectionStore.history.find(r => r.id === id);
    if (record) {
      record.status = status;
      record.errorMsg = errorMsg;
      record.duration = duration;
    }
  }

  static list(): Array<ConnectionRecord> { 
    return ConnectionStore.history; 
  }
  
  static remove(id: number): void {
    const record = ConnectionStore.history.find(r => r.id === id);
    if (record) {
      ConnectionStore.history = ConnectionStore.history.filter(r => r.id !== id);
      Logger.info(`历史: 删除 ${record.name}`);
      ConnectionStore.save();
    }
  }
  
  static clearAll(): void {
    ConnectionStore.history = [];
    Logger.info('历史: 清空所有记录');
    ConnectionStore.save();
  }

  /**
   * 获取已保存的密码（解密）
   */
  static getPassword(record: ConnectionRecord): string {
    if (record.encryptedPassword) {
      return ConnectionStore.decryptPassword(record.encryptedPassword);
    }
    return '';
  }
  
  /**
   * 导出配置文件（JSON格式）
   */
  static exportConfig(): string {
    const account = AccountManager.getCurrentAccount();
    
    interface ConnectionExport {
      id: number;
      name: string;
      host: string;
      port: number;
      username: string;
      authType: AuthType;
      encryptedPassword?: string;
      timestamp: number;
    }
    
    interface ExportData {
      version: string;
      exportTime: string;
      accountId: string;
      accountName: string;
      connections: ConnectionExport[];
    }
    
    const exportData: ExportData = {
      version: '1.0',
      exportTime: new Date().toISOString(),
      accountId: account?.openId || 'anonymous',
      accountName: account?.displayName || '未登录用户',
      connections: ConnectionStore.history.map(record => {
        const conn: ConnectionExport = {
          id: record.id,
          name: record.name,
          host: record.host,
          port: record.port,
          username: record.username,
          authType: record.authType,
          encryptedPassword: record.encryptedPassword,
          timestamp: record.timestamp
        };
        return conn;
      })
    };
    
    Logger.info(`导出配置: ${exportData.connections.length}条记录`);
    return JSON.stringify(exportData, null, 2);
  }
  
  /**
   * 导入配置文件
   */
  static async importConfig(jsonContent: string): Promise<ImportResult> {
    interface ConnectionImport {
      id: number;
      name: string;
      host: string;
      port: number;
      username: string;
      authType: AuthType;
      encryptedPassword?: string;
      timestamp: number;
    }
    
    interface ImportData {
      version: string;
      accountName: string;
      connections: ConnectionImport[];
    }
    
    try {
      const importData: ImportData = JSON.parse(jsonContent) as ImportData;
      
      // 验证数据格式
      if (!importData.version || !importData.connections) {
        throw new Error('无效的配置文件格式');
      }
      
      const account = AccountManager.getCurrentAccount();
      
      Logger.info(`导入配置: 来源账号=${importData.accountName}, 当前账号=${account?.displayName || '未登录'}`);
      
      let successCount = 0;
      let failedCount = 0;
      
      for (const conn of importData.connections) {
        try {
          // 检查是否已存在
          const existingIndex = ConnectionStore.history.findIndex(r => 
            r.host === conn.host && 
            r.port === conn.port && 
            r.username === conn.username
          );
          
          const record: ConnectionRecord = {
            id: existingIndex >= 0 ? ConnectionStore.history[existingIndex].id : ConnectionStore.seq++,
            name: conn.name,
            host: conn.host,
            port: conn.port,
            username: conn.username,
            authType: conn.authType,
            time: ConnectionStore.formatTime(new Date(conn.timestamp)),
            timestamp: conn.timestamp,
            encryptedPassword: conn.encryptedPassword
          };
          
          // 如果存在相同配置，删除旧的
          if (existingIndex >= 0) {
            ConnectionStore.history.splice(existingIndex, 1);
          }
          
          ConnectionStore.history.unshift(record);
          successCount++;
          
        } catch (err) {
          Logger.error(`导入单条记录失败: ${err}`);
          failedCount++;
        }
      }
      
      // 保存到数据库
      await ConnectionStore.save();
      
      Logger.info(`导入完成: 成功${successCount}条, 失败${failedCount}条`);
      
      const result: ImportResult = {
        success: successCount,
        failed: failedCount,
        total: importData.connections.length
      };
      return result;
      
    } catch (err) {
      const error = err as Error;
      Logger.error(`导入配置失败: ${error.message}`);
      throw new Error(`导入失败: ${error.message}`);
    }
  }
  
  static formatTime(date: Date): string {
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const hh = date.getHours().toString().padStart(2,'0');
    const mm = date.getMinutes().toString().padStart(2,'0');
    
    // 今天
    if (diff < 24 * 60 * 60 * 1000 && now.getDate() === date.getDate()) {
      return `今天 ${hh}:${mm}`;
    }
    // 昨天
    else if (diff < 48 * 60 * 60 * 1000 && now.getDate() - date.getDate() === 1) {
      return `昨天 ${hh}:${mm}`;
    }
    // 其他
    else {
      const month = (date.getMonth() + 1).toString().padStart(2, '0');
      const day = date.getDate().toString().padStart(2, '0');
      return `${month}-${day} ${hh}:${mm}`;
    }
  }
  
  // 兼容旧接口
  static nowLabel(): string {
    return ConnectionStore.formatTime(new Date());
  }
}

export class KeyStore {
  private static seq: number = 1;
  private static keys: Array<ImportedKey> = [];

  static importKey(name: string, content: string, publicKey?: string, passphrase?: string): ImportedKey {
    const fingerprint = SecurityUtils.sha256Hex(content);
    const k: ImportedKey = { id: KeyStore.seq++, name, content, publicKey, passphrase, fingerprint };
    KeyStore.keys.unshift(k);
    Logger.info(`密钥: 导入 ${name}${fingerprint ? ` fingerprint=${fingerprint.slice(0, 12)}…` : ''}`);
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
    const key = KeyStore.keys.find(k => k.id === id);
    if (key) {
      KeyStore.keys = KeyStore.keys.filter(k => k.id !== id);
      Logger.info(`密钥: 删除 ${key.name}`);
    }
  }
}
