import { ConnectionStore } from '../common/Stores';
import { SSHEngine } from '../common/SSHEngine';
import { router } from '@kit.ArkUI';
import { taskpool } from '@kit.ArkTS';
import hilog from '@ohos.hilog';
import kessh from 'libkessh.so';

const LOG_DOMAIN = 0xD15D;
const LOG_TAG = 'Terminal';

// 移除ANSI转义序列
function stripAnsiCodes(text: string): string {
  let result = text;
  
  // 移除CSI序列: ESC[...letter (包括颜色、光标控制等)
  result = result.replace(/\x1b\[[0-9;?]*[a-zA-Z]/g, '');
  
  // 移除OSC序列: ESC]...ST (ST可以是BEL或ESC\)
  result = result.replace(/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)/g, '');
  
  // 移除其他ESC序列: ESC followed by single character
  result = result.replace(/\x1b[\(\)=>]/g, '');
  result = result.replace(/\x1b[7-8]/g, '');
  
  // 处理换行符
  result = result.replace(/\r\n/g, '\n');
  result = result.replace(/\r/g, '');
  
  // 移除其他控制字符(保留\n和\t)
  result = result.replace(/[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]/g, '');
  
  return result;
}

// 后台线程读取SSH输出
@Concurrent
function readSSHOutput(sessionId: number): string {
  try {
    const result: string = kessh.read(sessionId);
    return result;
  } catch (e) {
    return '';
  }
}

// 后台线程写入SSH输入
@Concurrent
function writeSSHInput(sessionId: number, data: string): void {
  try {
    kessh.write(sessionId, data);
  } catch (e) {
    // @Concurrent函数中不能使用外部LOG常量
    // 错误会在调用处处理
  }
}

@Entry
@Component
struct Terminal {
  @State lines: Array<string> = [];
  @State cmd: string = '';
  private sessionId: number = -1;
  private timerId: number = -1;
  private scroller: Scroller = new Scroller();
  private buffer: string = ''; // 缓存未完成的行

  private processOutput(chunk: string): void {
    // 移除ANSI转义序列
    const cleanChunk = stripAnsiCodes(chunk);
    if (cleanChunk.length === 0) return;
    
    // 合并到缓存
    this.buffer += cleanChunk;
    
    // 按行分割
    const linesArray = this.buffer.split('\n');
    
    // 最后一个可能是未完成的行,保留在buffer中
    this.buffer = linesArray.pop() || '';
    
    // 添加完整的行
    for (const line of linesArray) {
      if (line.trim().length > 0) {
        this.lines.push(line);
      }
    }
  }

  aboutToAppear(): void {
    const d = ConnectionStore.currentDraft;
    if (d) {
      this.lines = [
        `已连接到 ${d.username}@${d.host}:${d.port}`
      ];
      const port = parseInt(d.port || '22');
      if (d.privateKey) {
        // FIXME: Private key authentication is not yet supported
        this.lines.push('密钥认证功能暂未实现');
        // this.sessionId = SSHEngine.openSession(d.host, port, d.username, d.privateKey, d.publicKey || '', d.passphrase);
      } else {
        this.sessionId = SSHEngine.openSession(d.host, port, d.username, d.password || '');
      }
      // 在后台线程轮询读取输出
      if (this.sessionId > 0) {
        // 发送禁用bracketed paste mode的命令
        setTimeout(async () => {
          try {
            const task = new taskpool.Task(writeSSHInput, this.sessionId, 'printf "\\e[?2004l"\n');
            await taskpool.execute(task);
          } catch (e) {
            hilog.warn(LOG_DOMAIN, LOG_TAG, 'Failed to disable bracketed paste mode');
          }
        }, 500);
        
        const tid = setInterval(async () => {
          try {
            const task = new taskpool.Task(readSSHOutput, this.sessionId);
            const chunk = await taskpool.execute(task) as string;
            if (chunk && chunk.length > 0) {
              this.processOutput(chunk);
              // 滚动到底部
              setTimeout(() => {
                this.scroller.scrollEdge(Edge.Bottom);
              }, 50);
            }
          } catch (e) {
            const errorMsg: string = e instanceof Error ? e.message : String(e);
            hilog.error(LOG_DOMAIN, LOG_TAG, 'Read task error: %{public}s', errorMsg);
          }
        }, 200) as number;
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
      SSHEngine.closeSession(this.sessionId);
      this.sessionId = -1;
    }
  }

  private async run(): Promise<void> {
    if (!this.cmd || this.sessionId <= 0) { return; }
    const cmd = this.cmd;
    this.cmd = '';
    // 不在本地显示命令,等待服务器回显
    
    // 在后台线程写入命令
    try {
      const task = new taskpool.Task(writeSSHInput, this.sessionId, cmd + '\n');
      await taskpool.execute(task);
    } catch (e) {
      const errorMsg: string = e instanceof Error ? e.message : String(e);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Write command error: %{public}s', errorMsg);
      this.lines.push(`错误: ${errorMsg}`);
    }
  }

  build() {
    Column() {
      // 顶部标题栏（返回）
      Row() {
        Text('<')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick((): void => {
            router.back();
          })
        
        Text('终端')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 4 })
        Blank().layoutWeight(1)
      }
      .height(56)
      .width('100%')
      .padding({ left: 8, right: 16 })

      // 输出区
      Scroll(this.scroller) {
        Column({ space: 4 }) {
          ForEach(this.lines, (line: string, idx: number) => {
            Text(line)
              .fontSize(14)
              .fontFamily('monospace')
          }, (line: string, idx: number) => idx.toString())
        }
        .padding(12)
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .edgeEffect(EdgeEffect.Spring)

      // 输入区
      Row() {
        TextInput({ placeholder: '输入命令', text: this.cmd })
          .onChange((v: string): void => { this.cmd = v })
          .layoutWeight(1)
        Blank().width(8)
        Button('执行')
          .type(ButtonType.Normal)
          .height(40)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .fontColor(Color.White)
          .onClick((): void => { this.run(); })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }
}