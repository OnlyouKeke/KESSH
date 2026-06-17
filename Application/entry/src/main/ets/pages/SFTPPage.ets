import { ConnectionStore, ConnectionRecord } from '../common/Stores';
import { SSHEngine } from '../common/SSHEngine';
import { promptAction, router } from '@kit.ArkUI';
import { LynxBlank, LynxButton, LynxColumn, LynxList, LynxListItem, LynxRow, LynxText, LynxScroll } from '../common/LynxUI';
import { getLynxPalette, LynxPalette } from '../common/LynxTheme';
import { SettingsStore } from '../common/Stores';

interface SFTPFile {
  name: string;
  isDir: boolean;
  size: string;
  permissions: string;
}

@Entry
@Component
export default struct SFTPPage {
  @State currentPath: string = '/';
  @State files: SFTPFile[] = [];
  @State connected: boolean = false;
  @State connecting: boolean = false;
  @State status: string = '请选择主机进行连接';
  @State hosts: Array<ConnectionRecord> = [];
  @StorageLink(SettingsStore.DARK_MODE_KEY) darkMode: boolean = SettingsStore.darkMode;
  private sessionId: number = -1;
  private connectToken: number = 0;
  private disposed: boolean = false;
  private keepaliveTimerId: number = -1;
  private keepaliveFailures: number = 0;

  aboutToAppear(): void {
    this.disposed = false;
    this.hosts = ConnectionStore.list();
  }

  private getPalette(): LynxPalette {
    const p = getLynxPalette(this.darkMode);
    if (p) return p;
    return {
      pageBackground: '#F5F7FA',
      surface: '#FFFFFFFF',
      card: '#10E7F0F5',
      primaryText: '#0F1115',
      secondaryText: '#6B7280',
      border: '#11000000',
      accent: '#1E7DD6'
    };
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.connectToken++;
    this.closeCurrentSession();
  }

  private closeCurrentSession(): void {
    this.stopKeepalive();
    if (this.sessionId > 0) {
      SSHEngine.closeSession(this.sessionId);
      this.sessionId = -1;
    }
    this.connected = false;
    this.connecting = false;
  }

  private startKeepalive(): void {
    this.stopKeepalive();
    const intervalSeconds = SettingsStore.sessionKeepaliveInterval;
    if (intervalSeconds <= 0 || this.sessionId <= 0) {
      return;
    }
    this.keepaliveFailures = 0;
    this.keepaliveTimerId = setInterval(() => {
      if (this.disposed || this.sessionId <= 0) {
        this.stopKeepalive();
        return;
      }
      const ok = SSHEngine.sendKeepalive(this.sessionId);
      if (ok) {
        this.keepaliveFailures = 0;
        return;
      }
      this.keepaliveFailures++;
      const maxAttempts = SettingsStore.sessionKeepaliveAttempts > 0 ? SettingsStore.sessionKeepaliveAttempts : 1;
      if (this.keepaliveFailures >= maxAttempts) {
        this.status = 'SSH 保活失败，连接已断开';
        this.closeCurrentSession();
      }
    }, intervalSeconds * 1000) as number;
  }

  private stopKeepalive(): void {
    if (this.keepaliveTimerId > 0) {
      clearInterval(this.keepaliveTimerId);
      this.keepaliveTimerId = -1;
    }
    this.keepaliveFailures = 0;
  }

  private async connect(item: ConnectionRecord): Promise<void> {
    if (this.connecting) {
      return;
    }
    if (item.authType === 'key') {
      promptAction.showToast({ message: '密钥认证暂未支持' });
      return;
    }
    const password = ConnectionStore.getPassword(item);
    if (!password) {
      promptAction.showToast({ message: '请输入密码后连接' });
      ConnectionStore.currentDraft = ConnectionStore.draftForPasswordInput(item);
      router.pushUrl({ url: 'pages/AddHost' });
      return;
    }

    const token = ++this.connectToken;
    this.closeCurrentSession();
    this.connecting = true;
    this.status = `正在连接 ${item.host}...`;
    this.currentPath = '/';
    this.files = [];

    SSHEngine.configureKeepalive(SettingsStore.sessionKeepaliveInterval, SettingsStore.sessionKeepaliveAttempts);
    const sid = await SSHEngine.openSessionPasswordAsync(item.host, item.port, item.username, password);
    if (this.disposed || token !== this.connectToken) {
      if (sid > 0) {
        SSHEngine.closeSession(sid);
      }
      return;
    }

    this.connecting = false;
    if (sid > 0) {
      this.sessionId = sid;
      this.connected = true;
      this.status = '已连接';
      this.startKeepalive();
      this.listFiles('/');
    } else {
      this.status = '连接失败';
    }
  }

  private listFiles(path: string): void {
    if (this.sessionId <= 0) return;
    this.currentPath = path;
    const output = SSHEngine.listFiles(this.sessionId, path);
    // parsing ls -la output
    const lines = output.split('\n');
    const parsedFiles: SFTPFile[] = [];

    // Add parent directory entry if not root
    if (path !== '/' && path.length > 1) {
      parsedFiles.push({ name: '..', isDir: true, size: '', permissions: '' });
    }

    for (const line of lines) {
      if (line.trim().length === 0 || line.startsWith('total')) continue;
      // drwxr-xr-x    2 root     root          4096 Dec 22 10:00 .
      const parts = line.split(/\s+/);
      if (parts.length < 9) continue;

      const permissions = parts[0];
      const size = parts[4];
      // filename might contain spaces, so join the rest
      const name = parts.slice(8).join(' ');

      if (name === '.' || name === '..') continue;

      const isDir = permissions.startsWith('d');
      parsedFiles.push({ name, isDir, size, permissions });
    }

    // Sort directories first
    this.files = parsedFiles.sort((a, b) => {
      if (a.name === '..') return -1;
      if (b.name === '..') return 1;
      if (a.isDir && !b.isDir) return -1;
      if (!a.isDir && b.isDir) return 1;
      return a.name.localeCompare(b.name);
    });
  }

  private navigate(file: SFTPFile): void {
    if (!file.isDir) return;

    let newPath = '';
    if (file.name === '..') {
      // Go up
      const parts = this.currentPath.split('/');
      parts.pop(); // remove empty element after last slash if exists or current dir
      if (this.currentPath.endsWith('/')) parts.pop();
      newPath = parts.join('/') || '/';
    } else {
      // Go down
      newPath = this.currentPath.endsWith('/') ? `${this.currentPath}${file.name}` : `${this.currentPath}/${file.name}`;
    }
    this.listFiles(newPath);
  }

  build() {
    Column() {
      // Top bar
      LynxBlank({ style: { height: 36, width: '100%' } })
      LynxRow({ style: { height: 56, width: '100%', padding: { left: 16, right: 16 } } }) {
        LynxButton({
          label: '<',
          style: { height: 36, width: 36, backgroundColor: this.getPalette().card, borderRadius: 18 },
          onClick: (): void => router.back(),
        })
        LynxText({ content: 'SFTP 文件', style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 12 }, fontColor: this.getPalette().primaryText } })
        LynxBlank({ style: { layoutWeight: 1 } })
      }

      if (!this.connected) {
        // Host Selection
        LynxText({ content: this.status, style: { fontSize: 14, margin: { left: 16, bottom: 8 }, fontColor: this.getPalette().secondaryText } })
        if (this.hosts.length > 0) {
          LynxList({ divider: { strokeWidth: 1, color: '#11000000' }, edgeEffect: EdgeEffect.None }) {
            ForEach(this.hosts, (item: ConnectionRecord) => {
              LynxListItem({ style: { padding: { left: 16, right: 16, top: 8, bottom: 8 } } }) {
                LynxRow({
                  style: { padding: 16, backgroundColor: this.getPalette().surface, borderRadius: 16, opacity: this.connecting ? 0.6 : 1 },
                  onTap: (): void => { this.connect(item); }
                }) {
                  LynxColumn({ space: 4 }) {
                    LynxText({ content: item.name, style: { fontSize: 16, fontWeight: FontWeight.Medium, fontColor: this.getPalette().primaryText } })
                    LynxText({ content: item.host, style: { fontSize: 13, fontColor: this.getPalette().secondaryText } })
                  }
                  LynxBlank({ style: { layoutWeight: 1 } })
                  LynxText({ content: this.connecting ? '连接中' : '选择', style: { fontSize: 14, fontColor: this.getPalette().accent } })
                }
              }
            }, (item: ConnectionRecord) => item.id.toString())
          }
        } else {
          LynxText({ content: '无可用主机，请先添加主机', style: { fontSize: 14, margin: 16, fontColor: this.getPalette().secondaryText } })
        }
      } else {
        // File List
        LynxText({ content: `路径: ${this.currentPath}`, style: { fontSize: 14, margin: { left: 16, bottom: 8 }, fontColor: this.getPalette().secondaryText } })
        LynxScroll({ style: { layoutWeight: 1, backgroundColor: this.getPalette().surface }, scrollBar: BarState.Auto }) {
          Column() {
            ForEach(this.files, (file: SFTPFile, idx: number) => {
              LynxColumn({ style: { width: '100%' }, onTap: () => { this.navigate(file); } }) {
                 LynxRow({ style: { padding: 12, alignItems: ItemAlign.Center } }) {
                   LynxText({ content: file.isDir ? '📁' : '📄', style: { fontSize: 20, margin: { right: 12 } } })
                   LynxColumn({ style: { layoutWeight: 1 } }) {
                     LynxText({ content: file.name, style: { fontSize: 14, fontColor: this.getPalette().primaryText } })
                     if (file.name !== '..') {
                       LynxText({ content: `${file.permissions} | ${file.size}`, style: { fontSize: 10, fontColor: this.getPalette().secondaryText } })
                     }
                   }
                   if (file.isDir) {
                     LynxText({ content: '>', style: { fontSize: 14, fontColor: this.getPalette().secondaryText } })
                   }
                 }
                 LynxBlank({ style: { width: '100%', height: 1, backgroundColor: '#11000000' } })
              }
            }, (file: SFTPFile, idx: number) => idx.toString())
          }
          .width('100%')
          .padding(16)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageBackground)
  }
}
