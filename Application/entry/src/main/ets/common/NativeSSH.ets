import { Logger } from './Stores';

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
}

let nativeBinding: NativeSSHExports | null = null;
try {
  nativeBinding = requireNapi('sshnative');
  Logger.log('原生SSH: 已加载 N-API 模块');
} catch (e) {
  nativeBinding = null;
  Logger.log('原生SSH: 未检测到 N-API 模块，使用占位实现');
}

export class SSHEngine {
  static async connectPassword(host: string, port: number, username: string, password: string | undefined): Promise<boolean> {
    if (nativeBinding) {
      const ok = nativeBinding.connectPassword(host, port, username, password);
      return ok ? true : false;
    }
    Logger.log(`原生SSH(密码-占位): 连接到 ${username}@${host}:${port}`);
    return true;
  }

  static async connectKey(host: string, port: number, username: string, privateKey: string, passphrase?: string): Promise<boolean> {
    if (nativeBinding) {
      const ok = nativeBinding.connectKey(host, port, username, privateKey, passphrase);
      return ok ? true : false;
    }
    Logger.log(`原生SSH(密钥-占位): 连接到 ${username}@${host}:${port} 使用密钥`);
    return true;
  }

  static async connectKey2(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase?: string): Promise<boolean> {
    if (nativeBinding && nativeBinding.connectKey2) {
      const ok = nativeBinding.connectKey2(host, port, username, privateKey, publicKey, passphrase);
      return ok ? true : false;
    }
    Logger.log(`原生SSH(密钥2-占位): 连接到 ${username}@${host}:${port} 使用密钥对`);
    return true;
  }

  static execCommandPassword(host: string, port: number, username: string, password: string, command: string): string {
    if (nativeBinding && nativeBinding.execCommandPassword) {
      return nativeBinding.execCommandPassword(host, port, username, password, command);
    }
    Logger.log(`原生SSH(命令-密码-占位): 在 ${username}@${host}:${port} 执行 ${command}`);
    return `占位输出: ${command}`;
  }

  static execCommandKey(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase: string | undefined, command: string): string {
    if (nativeBinding && nativeBinding.execCommandKey) {
      return nativeBinding.execCommandKey(host, port, username, privateKey, publicKey, passphrase, command);
    }
    Logger.log(`原生SSH(命令-密钥-占位): 在 ${username}@${host}:${port} 执行 ${command}`);
    return `占位输出: ${command}`;
  }

  static openSessionPassword(host: string, port: number, username: string, password: string): number {
    if (nativeBinding && nativeBinding.openSessionPassword) {
      return nativeBinding.openSessionPassword(host, port, username, password);
    }
    Logger.log(`原生SSH(会话-密码-占位): 打开到 ${username}@${host}:${port} 的会话`);
    return Math.floor(Math.random() * 1000) + 1; // 返回随机会话ID
  }

  static openSessionKey2(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase?: string): number {
    if (nativeBinding && nativeBinding.openSessionKey2) {
      return nativeBinding.openSessionKey2(host, port, username, privateKey, publicKey, passphrase);
    }
    Logger.log(`原生SSH(会话-密钥-占位): 打开到 ${username}@${host}:${port} 的会话`);
    return Math.floor(Math.random() * 1000) + 1; // 返回随机会话ID
  }

  static termWrite(sessionId: number, data: string): boolean {
    if (nativeBinding && nativeBinding.termWrite) {
      return nativeBinding.termWrite(sessionId, data);
    }
    Logger.log(`原生SSH(终端写-占位): 会话 ${sessionId} 写入 ${data}`);
    return true;
  }

  static termRead(sessionId: number): string {
    if (nativeBinding && nativeBinding.termRead) {
      return nativeBinding.termRead(sessionId);
    }
    // 占位实现：返回随机输出
    if (Math.random() < 0.1) {
      return `$ 占位输出 ${new Date().getTime()}`;
    }
    return '';
  }

  static termClose(sessionId: number): void {
    if (nativeBinding && nativeBinding.termClose) {
      nativeBinding.termClose(sessionId);
      return;
    }
    Logger.log(`原生SSH(终端关闭-占位): 关闭会话 ${sessionId}`);
  }
}