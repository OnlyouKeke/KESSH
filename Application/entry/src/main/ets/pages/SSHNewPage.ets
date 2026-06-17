import { promptAction, router } from '@kit.ArkUI';
import { LynxBlank, LynxButton, LynxColumn, LynxRow, LynxScroll, LynxText, LynxTextInput } from '../common/LynxUI';
import { getLynxPalette, LynxPalette } from '../common/LynxTheme';
import { ConnectionStore, ConnectionDraft } from '../common/Stores';
import { SettingsStore } from '../common/Stores';

interface ConnectionOption {
  key: string;
  title: string;
  description: string;
  icon: string;
  elevated?: boolean;
}

const OPTIONS: Array<ConnectionOption> = [
  { key: 'local', title: '本地', description: '无需远程主机启动本地会话', icon: '💻', elevated: true },
  { key: 'add', title: '添加主机', description: '通过 SSH 连接到远程机器', icon: '🔑' },
  { key: 'sftp', title: 'SFTP 连接', description: '通过 SSH 安全传输文件', icon: '📦' }
];

@Entry
@Component
export default struct SSHNewPage {
  @StorageLink(SettingsStore.DARK_MODE_KEY) darkMode: boolean = SettingsStore.darkMode;
  @State quickCmd: string = '';

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

  private onSelect(option: ConnectionOption): void {
    if (option.key === 'local') {
      promptAction.showToast({ message: '本地 Shell 暂不支持' });
    } else if (option.key === 'add') {
      ConnectionStore.currentDraft = null;
      router.pushUrl({ url: 'pages/AddHost' });
    } else if (option.key === 'sftp') {
      router.pushUrl({ url: 'pages/SFTPPage' });
    }
  }

  private parseUserHost(value: string): ConnectionDraft | null {
    const at = value.split('@');
    if (at.length !== 2 || !at[0] || !at[1]) {
      return null;
    }
    return {
      username: at[0],
      host: at[1],
      port: '22',
      password: ''
    };
  }

  private parseQuickCommand(cmd: string): ConnectionDraft | null {
    const sshWithPortAfter = /^ssh\s+([^\s@]+)@([^\s@]+)\s+-p\s+(\d+)$/;
    const sshWithPortBefore = /^ssh\s+-p\s+(\d+)\s+([^\s@]+)@([^\s@]+)$/;
    const sshNoPort = /^ssh\s+([^\s@]+)@([^\s@]+)$/;

    let match = cmd.match(sshWithPortAfter);
    if (match) {
      return { username: match[1], host: match[2], port: match[3], password: '' };
    }
    match = cmd.match(sshWithPortBefore);
    if (match) {
      return { username: match[2], host: match[3], port: match[1], password: '' };
    }
    match = cmd.match(sshNoPort);
    if (match) {
      return { username: match[1], host: match[2], port: '22', password: '' };
    }
    return this.parseUserHost(cmd);
  }

  private parseAndConnect(): void {
    const cmd = this.quickCmd.trim();
    if (!cmd) return;

    const draft = this.parseQuickCommand(cmd);
    if (!draft) {
      promptAction.showToast({ message: '格式错误: ssh user@host -p port' });
      return;
    }
    const validation = ConnectionStore.validateDraft(draft);
    if (validation) {
      promptAction.showToast({ message: validation });
      return;
    }
    ConnectionStore.currentDraft = ConnectionStore.normalizeDraft(draft);
    router.pushUrl({ url: 'pages/AddHost' });
  }

  build() {
    Column() {
      LynxScroll({ style: { width: '100%', height: '100%', backgroundColor: this.getPalette().pageBackground }, scrollBar: BarState.Off }) {
        LynxColumn({ space: 16, style: { padding: { left: 16, right: 16, bottom: 24 } } }) {
          LynxRow({ space: 12, style: { width: '100%' } }) {
            LynxTextInput({
              placeholder: "搜索或 'ssh user@hostname -p port'",
              text: this.quickCmd,
              style: { height: 44, padding: { left: 16, right: 16 }, backgroundColor: this.getPalette().card, borderRadius: 14, layoutWeight: 1 },
              onChange: (v: string): void => { this.quickCmd = v; }
            })
            LynxButton({
              label: '连接',
              style: { height: 44, width: 64, backgroundColor: this.getPalette().accent, fontColor: Color.White, borderRadius: 14 },
              onClick: (): void => { this.parseAndConnect(); }
            })
          }

          LynxColumn({ space: 6 }) {
            LynxText({ content: '连接方式', style: { fontSize: 18, fontWeight: FontWeight.Medium, fontColor: this.getPalette().primaryText } })
            LynxText({ content: '通过 SSH 连接，发现设备或使用串口。', style: { fontSize: 13, fontColor: this.getPalette().secondaryText } })
          }

          LynxColumn({ space: 12 }) {
            ForEach(OPTIONS, (item: ConnectionOption) => {
              LynxColumn({
                space: 8,
                style: {
                  padding: { left: 16, right: 16, top: 14, bottom: 14 },
                  backgroundColor: item.elevated ? this.getPalette().accent : this.getPalette().surface,
                  borderRadius: 18
                },
                onTap: (): void => { this.onSelect(item); }
              }) {
                LynxRow() {
                  LynxText({ content: item.icon, style: { fontSize: 20, margin: { right: 12 }, fontColor: this.getPalette().primaryText } })

                  LynxColumn({ space: 4 }) {
                    LynxText({ content: item.title, style: { fontSize: 16, fontWeight: FontWeight.Medium, fontColor: this.getPalette().primaryText } })
                    LynxText({ content: item.description, style: { fontSize: 13, fontColor: this.getPalette().secondaryText } })
                  }

                  LynxBlank({ style: { layoutWeight: 1 } })

                  LynxText({ content: '>', style: { fontSize: 18, fontColor: this.getPalette().secondaryText } })
                }
              }
            }, (item: ConnectionOption) => item.key)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
