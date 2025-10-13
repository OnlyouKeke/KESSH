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
  Logger.log('原生SSH: 未检测到 N-API 模块');
}

export class SSHEngine {
  static async connectPassword(host: string, port: number, username: string, password: string | undefined): Promise<boolean> {
    if (nativeBinding) {
      const ok = nativeBinding.connectPassword(host, port, username, password);
      return ok ? true : false;
    }
    Logger.log(`原生SSH: 未启用原生模块，无法进行密码方式连接 ${username}@${host}:${port}`);
    return false;
  }

  static async connectKey(host: string, port: number, username: string, privateKey: string, passphrase?: string): Promise<boolean> {
    if (nativeBinding) {
      const ok = nativeBinding.connectKey(host, port, username, privateKey, passphrase);
      return ok ? true : false;
    }
    Logger.log(`原生SSH: 未启用原生模块，无法进行密钥方式连接 ${username}@${host}:${port}`);
    return false;
  }

  static async connectKey2(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase?: string): Promise<boolean> {
    if (nativeBinding && nativeBinding.connectKey2) {
      const ok = nativeBinding.connectKey2(host, port, username, privateKey, publicKey, passphrase);
      return ok ? true : false;
    }
    Logger.log(`原生SSH: 未启用原生模块，无法进行密钥对方式连接 ${username}@${host}:${port}`);
    return false;
  }

  static execCommandPassword(host: string, port: number, username: string, password: string, command: string): string {
    if (nativeBinding && nativeBinding.execCommandPassword) {
      return nativeBinding.execCommandPassword(host, port, username, password, command);
    }
    Logger.log(`原生SSH: 未启用原生模块，无法执行命令(密码) ${username}@${host}:${port} -> ${command}`);
    return '';
  }

  static execCommandKey(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase: string | undefined, command: string): string {
    if (nativeBinding && nativeBinding.execCommandKey) {
      return nativeBinding.execCommandKey(host, port, username, privateKey, publicKey, passphrase, command);
    }
    Logger.log(`原生SSH: 未启用原生模块，无法执行命令(密钥) ${username}@${host}:${port} -> ${command}`);
    return '';
  }

  static openSessionPassword(host: string, port: number, username: string, password: string): number {
    if (nativeBinding && nativeBinding.openSessionPassword) {
      return nativeBinding.openSessionPassword(host, port, username, password);
    }
    Logger.log(`原生SSH: 未启用原生模块，无法打开会话(密码) ${username}@${host}:${port}`);
    return -1;
  }

  static openSessionKey2(host: string, port: number, username: string, privateKey: string, publicKey: string, passphrase?: string): number {
    if (nativeBinding && nativeBinding.openSessionKey2) {
      return nativeBinding.openSessionKey2(host, port, username, privateKey, publicKey, passphrase);
    }
    Logger.log(`原生SSH: 未启用原生模块，无法打开会话(密钥) ${username}@${host}:${port}`);
    return -1;
  }

  static termWrite(sessionId: number, data: string): boolean {
    if (nativeBinding && nativeBinding.termWrite) {
      return nativeBinding.termWrite(sessionId, data);
    }
    Logger.log(`原生SSH: 未启用原生模块，无法写入终端 会话=${sessionId}`);
    return false;
  }

  static termRead(sessionId: number): string {
    if (nativeBinding && nativeBinding.termRead) {
      return nativeBinding.termRead(sessionId);
    }
    return '';
  }

  static termClose(sessionId: number): void {
    if (nativeBinding && nativeBinding.termClose) {
      nativeBinding.termClose(sessionId);
      return;
    }
  }
}

