import { ConnectionStore } from '../common/Stores';
import { SSHEngine } from '../common/NativeSSH';
import { router } from '@kit.ArkUI';
import { LynxBlank, LynxButton, LynxColumn, LynxRow, LynxScroll, LynxText, LynxTextInput } from '../common/LynxUI';
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

  private get palette(): LynxPalette { return getLynxPalette(this.darkMode); }

  aboutToAppear(): void {
    const d = ConnectionStore.currentDraft;
    if (d) {
      this.lines = [
        `已连接到 ${d.username}@${d.host}:${d.port}`
      ];
      const port = parseInt(d.port || '22');
      if (d.privateKey) {
        this.sessionId = SSHEngine.openSessionKey2(d.host, port, d.username, d.privateKey, d.publicKey || '', d.passphrase);
      } else {
        this.sessionId = SSHEngine.openSessionPassword(d.host, port, d.username, d.password || '');
      }
      // 轮询读取输出
        if (this.sessionId > 0) {
          const tid = setInterval(() => {
            const chunk: string = SSHEngine.termRead(this.sessionId);
            if (chunk && chunk.length > 0) {
              this.lines.push(chunk);
            }
        }, 150) as number;
        this.timerId = tid;
      } else {
        this.lines.push('打开终端会话失败');
      }
    } else {
      this.lines = [ '未找到连接信息' ];
    }
  }

  aboutToDisappear(): void {
    if (this.timerId > 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.sessionId > 0) {
      SSHEngine.termClose(this.sessionId);
      this.sessionId = -1;
    }
  }

  private async run(): Promise<void> {
    if (!this.cmd || this.sessionId <= 0) { return; }
    const cmd = this.cmd;
    this.cmd = '';
    this.lines.push(`$ ${cmd}`);
    SSHEngine.termWrite(this.sessionId, cmd + '\n');
  }

  build() {
    LynxColumn({ style: { width: '100%', height: '100%', backgroundColor: this.palette.pageBackground } }) {
      // 顶部标题栏（返回）
      LynxBlank({ style: { height: 36, width: '100%' } })
      LynxRow({ style: { height: 56, width: '100%', padding: { left: 16, right: 16 } } }) {
        LynxButton({
          label: '<',
          style: { height: 36, width: 36, backgroundColor: this.palette.card, borderRadius: 18 },
          onClick: (): void => router.back(),
        })
        LynxText({ content: '终端', style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 12 }, fontColor: this.palette.primaryText } })
        LynxBlank({ style: { layoutWeight: 1 } })
      }

      // 输出区
      LynxScroll({ style: { layoutWeight: 1 }, scrollBar: BarState.Off }) {
        LynxColumn({ space: 4, style: { padding: { left: 16, right: 16, top: 8, bottom: 8 }, width: '100%' } }) {
          ForEach(this.lines, (line: string, idx: number) => {
            LynxText({ content: line, style: { fontSize: 13, fontColor: this.palette.primaryText } })
          }, (line: string, idx: number) => idx.toString())
        }
      }

      // 输入区
      LynxRow({ style: { padding: { left: 16, right: 16, top: 8, bottom: 16 }, width: '100%' } }) {
        LynxTextInput({ placeholder: '输入命令', text: this.cmd, style: { layoutWeight: 1, backgroundColor: this.palette.surface, borderRadius: 12 } , onChange: (v: string): void => { this.cmd = v } })
        LynxBlank({ style: { width: 12 } })
        LynxButton({
          label: '执行',
          style: { height: 40, backgroundColor: this.palette.accent, fontColor: Color.White, borderRadius: 12 },
          onClick: (): void => { this.run(); }
        })
      }
    }
  }
}