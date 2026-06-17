/**
 * Native bridge between the ReactLynx UI and the HarmonyOS host.
 *
 * The HarmonyOS shell registers a `KesshHost` NativeModule that exposes the
 * SSH operations, settings, storage, and network tools to Lynx. All calls
 * are async; if the host has not yet bridged a method the stub fails closed
 * with an obvious error, never silently.
 */

'background only';

import type { ReactNode } from '@lynx-js/react';

declare const NativeModules: Record<string, Record<string, (...args: unknown[]) => Promise<unknown>>>;

export interface ConnectionRecord {
  id: number;
  name: string;
  host: string;
  port: number;
  username: string;
  authType: 'password' | 'key';
  time: string;
}

export interface ConnectionDraft {
  host: string;
  port: number;
  username: string;
  password?: string;
  privateKey?: string;
  publicKey?: string;
  passphrase?: string;
  isEditing?: boolean;
  editingId?: number;
}

export interface Snippet {
  id: number;
  title: string;
  command: string;
}

export interface ImportedKey {
  id: number;
  name: string;
  fingerprint?: string;
}

export interface SessionSettings {
  keepaliveInterval: number;
  keepaliveAttempts: number;
  terminalFontFamily: string;
  terminalFontSize: number;
}

export interface AppSettings {
  darkMode: boolean;
  savePassword: boolean;
  session: SessionSettings;
}

export interface FontOption {
  key: string;
  label: string;
  description: string;
  family: string;
}

export interface SystemMetrics {
  cpuUsage: number;
  cpuDetail: string;
  memoryUsage: number;
  memoryDetail: string;
  diskUsage: number;
  diskDetail: string;
  lastUpdate: string;
}

const HOST = (() => {
  try {
    return NativeModules?.KesshHost ?? null;
  } catch {
    return null;
  }
})();

function notBridged(method: string): never {
  throw new Error(
    `KesshHost.${method} is not bridged yet. ` +
    `The HarmonyOS shell must register a NativeModule named "KesshHost" before this UI can run on-device.`
  );
}

async function call<T>(method: string, args: unknown[] = []): Promise<T> {
  if (!HOST || typeof HOST[method] !== 'function') {
    notBridged(method);
  }
  return await HOST[method](...args) as T;
}

export const KesshHost = {
  // Settings ----------------------------------------------------------
  async getSettings(): Promise<AppSettings> {
    return call<AppSettings>('getSettings');
  },
  async setDarkMode(value: boolean): Promise<void> {
    return call<void>('setDarkMode', [value]);
  },
  async setSavePassword(value: boolean): Promise<void> {
    return call<void>('setSavePassword', [value]);
  },
  async setSessionSettings(settings: Partial<SessionSettings>): Promise<void> {
    return call<void>('setSessionSettings', [settings]);
  },
  async listFontOptions(): Promise<FontOption[]> {
    return call<FontOption[]>('listFontOptions');
  },

  // Connection store --------------------------------------------------
  async listConnections(): Promise<ConnectionRecord[]> {
    return call<ConnectionRecord[]>('listConnections');
  },
  async addConnection(draft: ConnectionDraft): Promise<ConnectionRecord> {
    return call<ConnectionRecord>('addConnection', [draft]);
  },
  async savePassword(recordId: number, password: string): Promise<void> {
    return call<void>('savePassword', [recordId, password]);
  },
  async hasPassword(recordId: number): Promise<boolean> {
    return call<boolean>('hasPassword', [recordId]);
  },

  // Snippets ----------------------------------------------------------
  async listSnippets(): Promise<Snippet[]> {
    return call<Snippet[]>('listSnippets');
  },
  async addSnippet(title: string, command: string): Promise<Snippet> {
    return call<Snippet>('addSnippet', [title, command]);
  },
  async removeSnippet(id: number): Promise<void> {
    return call<void>('removeSnippet', [id]);
  },

  // Keys --------------------------------------------------------------
  async listKeys(): Promise<ImportedKey[]> {
    return call<ImportedKey[]>('listKeys');
  },
  async importKey(name: string, content: string, publicKey?: string, passphrase?: string): Promise<ImportedKey> {
    return call<ImportedKey>('importKey', [name, content, publicKey, passphrase]);
  },
  async removeKey(id: number): Promise<void> {
    return call<void>('removeKey', [id]);
  },

  // SSH ---------------------------------------------------------------
  async openSession(draft: ConnectionDraft): Promise<number> {
    return call<number>('openSession', [draft]);
  },
  async closeSession(sessionId: number): Promise<void> {
    return call<void>('closeSession', [sessionId]);
  },
  async termWrite(sessionId: number, data: string): Promise<void> {
    return call<void>('termWrite', [sessionId, data]);
  },
  async termRead(sessionId: number): Promise<string> {
    return call<string>('termRead', [sessionId]);
  },
  async sendKeepalive(sessionId: number): Promise<boolean> {
    return call<boolean>('sendKeepalive', [sessionId]);
  },
  async listFiles(sessionId: number, remotePath: string): Promise<string> {
    return call<string>('listFiles', [sessionId, remotePath]);
  },
  async downloadFile(sessionId: number, remotePath: string): Promise<string> {
    return call<string>('downloadFile', [sessionId, remotePath]);
  },
  async uploadFile(sessionId: number, remotePath: string, content: string): Promise<number> {
    return call<number>('uploadFile', [sessionId, remotePath, content]);
  },

  // Monitor / metrics -------------------------------------------------
  async fetchMetrics(sessionId: number): Promise<SystemMetrics> {
    return call<SystemMetrics>('fetchMetrics', [sessionId]);
  },

  // Logs --------------------------------------------------------------
  async listLogs(): Promise<string[]> {
    return call<string[]>('listLogs');
  },
  async clearLogs(): Promise<void> {
    return call<void>('clearLogs');
  },

  // Toast / prompt ----------------------------------------------------
  async showToast(message: string): Promise<void> {
    return call<void>('showToast', [message]);
  },
  async writeClipboard(text: string): Promise<void> {
    return call<void>('writeClipboard', [text]);
  },

  // Network tools -----------------------------------------------------
  async pingHost(host: string, count: number): Promise<string> {
    return call<string>('pingHost', [host, count]);
  },
  async testPort(host: string, port: number, timeoutMs: number): Promise<string> {
    return call<string>('testPort', [host, port, timeoutMs]);
  }
};

export type LucideName = string;
export type { ReactNode };
