import { ConnectionStore } from '../common/Stores';
import { SSHEngine } from '../common/SSHEngine';
import { promptAction, router } from '@kit.ArkUI';
import { LynxBlank, LynxButton, LynxRow, LynxScroll, LynxText, LynxTextInput } from '../common/LynxUI';
import { getLynxPalette, LynxPalette } from '../common/LynxTheme';
import { SettingsStore } from '../common/Stores';

@Entry
@Component
export default struct Terminal {
  @State lines: Array<string> = [];
  @State cmd: string = '';
  @StorageLink(SettingsStore.DARK_MODE_KEY) darkMode: boolean = SettingsStore.darkMode;
  private sessionId: number = -1;
  private timerId: number = -1;
  private keepaliveTimerId: number = -1;
  private polling: boolean = false;
  private disposed: boolean = false;
  private pollToken: number = 0;
  private openToken: number = 0;
  private keepaliveFailures: number = 0;
  private readonly pollIntervalMs: number = 150;

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

  private appendLine(line: string): void {
    this.lines = [...this.lines, line];
  }

  private schedulePoll(token: number, delayMs: number): void {
    if (!this.polling || token !== this.pollToken || this.disposed) {
      return;
    }
    if (this.timerId > 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    this.timerId = setTimeout(() => {
      if (!this.polling || token !== this.pollToken || this.sessionId <= 0 || this.disposed) {
        return;
      }
      try {
        const chunk = SSHEngine.termRead(this.sessionId);
        if (this.polling && token === this.pollToken && chunk && chunk.length > 0) {
          this.appendLine(chunk);
        }
      } catch (_) {
      } finally {
        this.schedulePoll(token, this.pollIntervalMs);
      }
    }, delayMs) as number;
  }

  private startPolling(): void {
    if (this.polling || this.sessionId <= 0 || this.disposed) {
      return;
    }
    this.polling = true;
    const token = ++this.pollToken;
    this.schedulePoll(token, 0);
  }

  private stopPolling(): void {
    this.polling = false;
    this.pollToken++;
    if (this.timerId > 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
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
        this.appendLine('SSH 保活失败，连接已断开');
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

  private closeCurrentSession(): void {
    this.stopPolling();
    this.stopKeepalive();
    if (this.sessionId > 0) {
      SSHEngine.termClose(this.sessionId);
      this.sessionId = -1;
    }
  }

  private async openDraft(): Promise<void> {
    const token = ++this.openToken;
    this.closeCurrentSession();

    const d = ConnectionStore.currentDraft;
    if (!d) {
      this.lines = [ '未找到连接信息' ];
      return;
    }

    const validation = ConnectionStore.validateDraft(d);
    if (validation) {
      this.lines = [ validation ];
      return;
    }
    const port = ConnectionStore.parsePort(d.port || '22');
    if (port === null) {
      this.lines = [ '端口必须是 1-65535 的数字' ];
      return;
    }

    this.lines = [ `正在连接 ${d.username}@${d.host}:${port}...` ];

    if (d.privateKey) {
      this.appendLine('密钥认证暂未支持，请改用密码连接');
      return;
    }
    if (!d.password) {
      this.appendLine('缺少密码，请返回主机页补充密码');
      return;
    }

    SSHEngine.configureKeepalive(SettingsStore.sessionKeepaliveInterval, SettingsStore.sessionKeepaliveAttempts);
    const sid = await SSHEngine.openSessionPasswordAsync(d.host, port, d.username, d.password);
    if (this.disposed || token !== this.openToken) {
      if (sid > 0) {
        SSHEngine.termClose(sid);
      }
      return;
    }

    if (sid > 0) {
      this.sessionId = sid;
      this.appendLine('连接成功');
      this.startPolling();
      this.startKeepalive();
    } else {
      this.appendLine('打开终端会话失败');
    }
  }

  aboutToAppear(): void {
    this.disposed = false;
    this.openDraft();
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.openToken++;
    this.closeCurrentSession();
  }

  private async run(): Promise<void> {
    if (!this.cmd) { return; }
    if (this.sessionId <= 0) {
      promptAction.showToast({ message: 'SSH 连接未就绪' });
      return;
    }
    const cmd = this.cmd;
    this.cmd = '';
    this.appendLine(`$ ${cmd}`);
    SSHEngine.termWrite(this.sessionId, cmd + '\n');
  }

  build() {
    Column() {
      // 顶部（返回）
      LynxBlank({ style: { height: 36, width: '100%' } })
      LynxRow({ style: { height: 56, width: '100%', padding: { left: 16, right: 16 } } }) {
        LynxButton({
          label: '<',
          style: { height: 36, width: 36, backgroundColor: this.getPalette().card, borderRadius: 18 },
          onClick: (): void => router.back(),
        })
        LynxText({ content: '终端', style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 12 }, fontColor: this.getPalette().primaryText } })
        LynxBlank({ style: { layoutWeight: 1 } })
      }

      // 输出区
      LynxScroll({ style: { layoutWeight: 1 }, scrollBar: BarState.Off }) {
        Column({ space: 4 }) {
          ForEach(this.lines, (line: string, idx: number) => {
            LynxText({ content: line, style: { fontSize: 13, fontColor: this.getPalette().primaryText } })
          }, (line: string, idx: number) => idx.toString())
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .width('100%')
      }

      // 输入区
      LynxRow({ style: { padding: { left: 16, right: 16, top: 8, bottom: 16 }, width: '100%' } }) {
        LynxTextInput({ placeholder: '输入命令', text: this.cmd, style: { layoutWeight: 1, backgroundColor: this.getPalette().surface, borderRadius: 12 } , onChange: (v: string): void => { this.cmd = v } })
        LynxBlank({ style: { width: 12 } })
        LynxButton({
          label: '执行',
          style: { height: 40, backgroundColor: this.getPalette().accent, fontColor: Color.White, borderRadius: 12 },
          onClick: (): void => { this.run(); }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageBackground);
  }
}
