import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  ConnectionDraft,
  ConnectionRecord,
  ConnectionStore,
  ImportedKey,
  KeyStore,
  Logger,
  SettingsStore,
  Snippet,
  SnippetStore
} from '../common/Stores';
import { SSHEngine } from '../common/SSHEngine';
import {
  ensureTerminalFontsRegistered,
  getTerminalFontOptions,
  TerminalFontOption
} from '../common/TerminalFonts';
import kessh from 'libkessh.so';

interface AppSettingsDTO {
  darkMode: boolean;
  savePassword: boolean;
  session: SessionSettingsDTO;
}

interface SessionSettingsDTO {
  keepaliveInterval: number;
  keepaliveAttempts: number;
  terminalFontFamily: string;
  terminalFontSize: number;
}

interface SessionSettingsPatch {
  keepaliveInterval?: number;
  keepaliveAttempts?: number;
  terminalFontFamily?: string;
  terminalFontSize?: number;
}

interface FontOptionDTO {
  key: string;
  label: string;
  description: string;
  family: string;
}

interface SystemMetricsDTO {
  cpuUsage: number;
  cpuDetail: string;
  memoryUsage: number;
  memoryDetail: string;
  diskUsage: number;
  diskDetail: string;
  lastUpdate: string;
}

/**
 * Bridge module exposed to the ReactLynx UI under the name `KesshHost`.
 *
 * The Lynx side declares the contract in `lynx-app/src/native/host.ts`; every
 * method here mirrors a method there 1:1 and returns plain JSON-serialisable
 * payloads. Methods are async so the Lynx caller can await them on the
 * background thread without blocking layout.
 *
 * Once `@lynx/lynx@next` is installed via ohpm, register this module from
 * `EntryAbility.onCreate()`:
 *
 *   import lynx from '@lynx/lynx';
 *   import { KesshHost } from './kessh/KesshHost';
 *   lynx.registerNativeModule('KesshHost', KesshHost.shared());
 *
 * The exact registration API name may differ between Lynx versions; see the
 * @lynx/lynx package documentation. The class itself does not depend on it.
 */
export class KesshHost {
  private static instance: KesshHost | null = null;

  static shared(): KesshHost {
    if (!KesshHost.instance) {
      KesshHost.instance = new KesshHost();
    }
    return KesshHost.instance;
  }

  // ---------------------------------------------------------------- settings

  async getSettings(): Promise<AppSettingsDTO> {
    SettingsStore.ensureInitialized();
    return {
      darkMode: SettingsStore.darkMode,
      savePassword: SettingsStore.savePassword,
      session: {
        keepaliveInterval: SettingsStore.sessionKeepaliveInterval,
        keepaliveAttempts: SettingsStore.sessionKeepaliveAttempts,
        terminalFontFamily: SettingsStore.terminalFontFamily,
        terminalFontSize: SettingsStore.terminalFontSize
      }
    };
  }

  async setDarkMode(value: boolean): Promise<void> {
    SettingsStore.setDarkMode(value);
  }

  async setSavePassword(value: boolean): Promise<void> {
    SettingsStore.setSavePassword(value);
  }

  async setSessionSettings(patch: SessionSettingsPatch): Promise<void> {
    if (typeof patch.keepaliveInterval === 'number') {
      await SettingsStore.setSessionKeepaliveInterval(patch.keepaliveInterval);
    }
    if (typeof patch.keepaliveAttempts === 'number') {
      await SettingsStore.setSessionKeepaliveAttempts(patch.keepaliveAttempts);
    }
    if (typeof patch.terminalFontFamily === 'string') {
      await SettingsStore.setTerminalFontFamily(patch.terminalFontFamily);
    }
    if (typeof patch.terminalFontSize === 'number') {
      await SettingsStore.setTerminalFontSize(patch.terminalFontSize);
    }
    SSHEngine.configureKeepalive(
      SettingsStore.sessionKeepaliveInterval,
      SettingsStore.sessionKeepaliveAttempts
    );
  }

  async listFontOptions(): Promise<FontOptionDTO[]> {
    ensureTerminalFontsRegistered();
    return getTerminalFontOptions().map((option: TerminalFontOption): FontOptionDTO => ({
      key: option.key,
      label: option.label,
      description: option.description,
      family: option.family
    }));
  }

  // --------------------------------------------------------------- connections

  async listConnections(): Promise<ConnectionRecord[]> {
    return ConnectionStore.list();
  }

  async addConnection(draft: ConnectionDraft): Promise<ConnectionRecord> {
    const validation = ConnectionStore.validateDraft(draft);
    if (validation) {
      throw new Error(validation);
    }
    const record = ConnectionStore.addFromDraft(draft, draft.privateKey ? 'key' : 'password');
    if (draft.password && SettingsStore.savePassword) {
      ConnectionStore.savePassword(record, draft.password);
    }
    return record;
  }

  async savePassword(recordId: number, password: string): Promise<void> {
    const record = ConnectionStore.getById(recordId);
    if (record) {
      ConnectionStore.savePassword(record, password);
    }
  }

  async hasPassword(recordId: number): Promise<boolean> {
    const record = ConnectionStore.getById(recordId);
    if (!record) return false;
    const password = ConnectionStore.getPassword(record);
    return !!password;
  }

  // ----------------------------------------------------------------- snippets

  async listSnippets(): Promise<Snippet[]> {
    return SnippetStore.list();
  }

  async addSnippet(title: string, command: string): Promise<Snippet> {
    SnippetStore.add(title, command);
    const list = SnippetStore.list();
    return list[list.length - 1];
  }

  async removeSnippet(id: number): Promise<void> {
    SnippetStore.remove(id);
  }

  // --------------------------------------------------------------------- keys

  async listKeys(): Promise<ImportedKey[]> {
    return KeyStore.list().map((key: ImportedKey): ImportedKey => {
      const safe: ImportedKey = {
        id: key.id,
        name: key.name,
        content: '',
        fingerprint: key.fingerprint
      };
      if (key.publicKey) {
        safe.publicKey = key.publicKey;
      }
      return safe;
    });
  }

  async importKey(name: string, content: string, publicKey?: string, passphrase?: string): Promise<ImportedKey> {
    const key = KeyStore.importKey(name, content, publicKey, passphrase);
    const safe: ImportedKey = {
      id: key.id,
      name: key.name,
      content: '',
      fingerprint: key.fingerprint
    };
    if (key.publicKey) {
      safe.publicKey = key.publicKey;
    }
    return safe;
  }

  async removeKey(id: number): Promise<void> {
    KeyStore.remove(id);
  }

  // ---------------------------------------------------------------- ssh shell

  async openSession(draft: ConnectionDraft): Promise<number> {
    const password = await this.resolvePassword(draft);
    const port = ConnectionStore.parsePort(`${draft.port ?? 22}`) ?? 22;
    SSHEngine.configureKeepalive(
      SettingsStore.sessionKeepaliveInterval,
      SettingsStore.sessionKeepaliveAttempts
    );
    return await SSHEngine.openSessionPasswordAsync(draft.host, port, draft.username, password);
  }

  private async resolvePassword(draft: ConnectionDraft): Promise<string> {
    if (draft.password && draft.password.length > 0) {
      return draft.password;
    }
    if (draft.editingId !== undefined) {
      const record = ConnectionStore.getById(draft.editingId);
      const stored = record ? ConnectionStore.getPassword(record) : null;
      if (stored) {
        return stored;
      }
    }
    return '';
  }

  async closeSession(sessionId: number): Promise<void> {
    SSHEngine.closeSession(sessionId);
  }

  async termWrite(sessionId: number, data: string): Promise<void> {
    SSHEngine.termWrite(sessionId, data);
  }

  async termRead(sessionId: number): Promise<string> {
    return SSHEngine.termRead(sessionId);
  }

  async sendKeepalive(sessionId: number): Promise<boolean> {
    return SSHEngine.sendKeepalive(sessionId);
  }

  async listFiles(sessionId: number, remotePath: string): Promise<string> {
    return SSHEngine.listFiles(sessionId, remotePath);
  }

  async downloadFile(sessionId: number, remotePath: string): Promise<string> {
    return SSHEngine.downloadFile(sessionId, remotePath);
  }

  async uploadFile(sessionId: number, remotePath: string, content: string): Promise<number> {
    return SSHEngine.uploadFile(sessionId, remotePath, content);
  }

  // ----------------------------------------------------------------- monitor

  async fetchMetrics(sessionId: number): Promise<SystemMetricsDTO> {
    const cpuRaw = SSHEngine.executeCommand(sessionId, "LANG=C top -bn1 | grep 'Cpu(s)' | head -n 1");
    const memRaw = SSHEngine.executeCommand(sessionId, "free -m | grep -E '^Mem'");
    const diskRaw = SSHEngine.executeCommand(sessionId, "df -h / | tail -n 1");

    const cpu = this.parseCpu(cpuRaw);
    const memory = this.parseMemory(memRaw);
    const disk = this.parseDisk(diskRaw);

    return {
      cpuUsage: cpu.usage,
      cpuDetail: cpu.detail,
      memoryUsage: memory.usage,
      memoryDetail: memory.detail,
      diskUsage: disk.usage,
      diskDetail: disk.detail,
      lastUpdate: new Date().toLocaleTimeString()
    };
  }

  private parseCpu(output: string): { usage: number; detail: string } {
    if (!output) {
      return { usage: 0, detail: '--' };
    }
    const idleMatch = output.match(/(\d+(?:\.\d+)?)\s*%?\s*id/i);
    if (idleMatch) {
      const idle = parseFloat(idleMatch[1]);
      return { usage: 100 - idle, detail: output.trim() };
    }
    const usageMatch = output.match(/(\d+(?:\.\d+)?)\s*us.*?(\d+(?:\.\d+)?)\s*sy/i);
    if (usageMatch) {
      return { usage: parseFloat(usageMatch[1]) + parseFloat(usageMatch[2]), detail: output.trim() };
    }
    return { usage: 0, detail: output.trim() };
  }

  private parseMemory(output: string): { usage: number; detail: string } {
    if (!output) {
      return { usage: 0, detail: '--' };
    }
    const columns = output.replace(/\s+/g, ' ').trim().split(' ');
    if (columns.length >= 4) {
      const total = parseFloat(columns[1]);
      const used = parseFloat(columns[2]);
      const free = parseFloat(columns[3]);
      const usage = total > 0 ? (used / total) * 100 : 0;
      return { usage, detail: `total ${total}MB · used ${used}MB · free ${free}MB` };
    }
    return { usage: 0, detail: output.trim() };
  }

  private parseDisk(output: string): { usage: number; detail: string } {
    if (!output) {
      return { usage: 0, detail: '--' };
    }
    const columns = output.replace(/\s+/g, ' ').trim().split(' ');
    if (columns.length >= 5) {
      const percent = columns[4].replace('%', '');
      return {
        usage: parseFloat(percent) || 0,
        detail: `size ${columns[1]} · used ${columns[2]} · avail ${columns[3]}`
      };
    }
    return { usage: 0, detail: output.trim() };
  }

  // -------------------------------------------------------------------- logs

  async listLogs(): Promise<string[]> {
    return Logger.list();
  }

  async clearLogs(): Promise<void> {
    Logger.clear();
  }

  // -------------------------------------------------------------- ui helpers

  async showToast(message: string): Promise<void> {
    promptAction.showToast({ message });
  }

  async writeClipboard(text: string): Promise<void> {
    if (!text) {
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const board = pasteboard.getSystemPasteboard();
    await board.setData(data);
  }

  // ----------------------------------------------------------- network tools

  async pingHost(host: string, count: number): Promise<string> {
    return kessh.pingHost(host, count);
  }

  async testPort(host: string, port: number, timeoutMs: number): Promise<string> {
    return kessh.testPort(host, port, timeoutMs);
  }
}

export default KesshHost;
