/**
 * Native bridge between the ReactLynx UI and the HarmonyOS host.
 *
 * The HarmonyOS shell registers a `KesshHost` NativeModule that exposes the
 * SSH operations (currently provided by `Application/entry/src/main/cpp/kessh.cpp`)
 * and a small storage / settings layer (currently `Stores.ets`).
 *
 * On the Lynx side, `NativeModules` is the standard background-only access
 * point. Calls return Promises so the UI can stay responsive.
 *
 * This module is the single source of truth for the Lynx → host contract.
 * If a method does not exist on the host yet, it falls back to a stub that
 * surfaces a clear "not implemented" error so the UI fails closed instead of
 * silently doing the wrong thing.
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

const HOST = (() => {
  // NativeModules can be undefined when running in the dev preview.
  // Fall back to no-op stubs so the UI still renders and the developer sees
  // the "not bridged yet" error in console.
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
  }
};

export type LucideName = string;

// Re-export the type used by render-prop children of lynx-ui Button/Switch
// so pages do not import from internal paths.
export type { ReactNode };
