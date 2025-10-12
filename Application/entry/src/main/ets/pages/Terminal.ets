import { ConnectionStore } from '../common/Stores';
import { SSHEngine } from '../common/NativeSSH';
import { router } from '@kit.ArkUI';

@Entry
@Component
export default struct Terminal {
  @State lines: Array<string> = [];
  @State cmd: string = '';
  private sessionId: number = -1;
  private timerId: number = -1;

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
          const chunk = SSHEngine.termRead(this.sessionId);
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
    Column() {
      // 顶部标题栏（返回）
      Blank().height(36).width('100%')
      Row() {
        Button('<')
          .type(ButtonType.Normal)
          .height(36)
          .width(36)
          .backgroundColor('#0F000000')
          .borderRadius(18)
          .onClick((): void => router.back())
        Text('终端')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
        Blank().layoutWeight(1)
      }
      .height(56)
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 输出区
      Scroll() {
        Column({ space: 4 }) {
          ForEach(this.lines, (line: string, idx: number) => {
            Text(line)
              .fontSize(13)
          }, (line: string, idx: number) => idx.toString())
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 输入区
      Row() {
        TextInput({ placeholder: '输入命令', text: this.cmd })
          .onChange((v: string): void => { this.cmd = v })
          .layoutWeight(1)
        Blank().width(12)
        Button('执行')
          .type(ButtonType.Normal)
          .height(40)
          .backgroundColor('#222222')
          .fontColor(Color.White)
          .borderRadius(12)
          .onClick((): void => { this.run(); })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}