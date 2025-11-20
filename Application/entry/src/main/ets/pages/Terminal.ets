import { ConnectionStore, SettingsStore } from '../common/Stores';
import { SSHEngine } from '../common/SSHEngine';
import { router, promptAction } from '@kit.ArkUI';
import { taskpool } from '@kit.ArkTS';
import { pasteboard } from '@kit.BasicServicesKit';
import { ensureTerminalFontsRegistered, resolveFontFamily, TerminalFontKey } from '../common/TerminalFonts';
import hilog from '@ohos.hilog';
import kessh from 'libkessh.so';

const LOG_DOMAIN = 0xD15D;
const LOG_TAG = 'Terminal';

interface QuickKey {
  label: string;
  sequence: string;
}

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
  @State showKeyMenu: boolean = false;
  private sessionId: number = -1;
  private timerId: number = -1;
  private keepaliveTimerId: number = -1;
  private keepaliveFailures: number = 0;
  private scroller: Scroller = new Scroller();
  private buffer: string = ''; // 缓存未完成的行
  private terminalFontFamily: string = 'monospace';
  private terminalFontSize: number = 14;
  private readonly quickKeys: Array<QuickKey> = [
    { label: 'Ctrl+C', sequence: '\u0003' },
    { label: 'Ctrl+Z', sequence: '\u001A' },
    { label: 'Ctrl+D', sequence: '\u0004' }
  ];

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
    ensureTerminalFontsRegistered();
    const selectedFont = SettingsStore.terminalFontFamily as TerminalFontKey;
    this.terminalFontFamily = resolveFontFamily(selectedFont);
    this.terminalFontSize = SettingsStore.terminalFontSize;

    const d = ConnectionStore.currentDraft;
    if (!d) {
      promptAction.showToast({ message: '未找到连接信息' });
      router.replaceUrl({ url: 'pages/Index' });
      return;
    }

    this.lines = [
      `正在连接 ${d.username}@${d.host}:${d.port}...`
    ];
    
    const port = parseInt(d.port || '22');
    
    try {
      SSHEngine.configureKeepalive(SettingsStore.sessionKeepaliveInterval, SettingsStore.sessionKeepaliveAttempts);
      // 尝试建立SSH连接
      if (d.privateKey) {
        // FIXME: Private key authentication is not yet supported
        promptAction.showToast({ message: '密钥认证功能暂未实现' });
        router.replaceUrl({ url: 'pages/Index' });
        return;
      } else {
        this.sessionId = SSHEngine.openSession(d.host, port, d.username, d.password || '');
      }
      
      // 检查连接是否成功
      if (this.sessionId <= 0) {
        // 连接失败，判断是否为网络问题
        const errorMsg = this.isNetworkError(d.host) ? '网络故障，无法连接服务器' : 'SSH连接失败';
        promptAction.showToast({ message: errorMsg });
        hilog.error(LOG_DOMAIN, LOG_TAG, 'SSH connection failed: sessionId=%{public}d', this.sessionId);
        // 不要立即返回，延迟返回首页避免应用退出
        setTimeout(() => {
          router.back();
      }, 1000);
      this.stopKeepaliveWatchdog();
      return;
    }
      
      // 连接成功
      this.lines = [
        `已连接到 ${d.username}@${d.host}:${d.port}`
      ];
      
      // 发送禁用bracketed paste mode的命令
      setTimeout(async () => {
        try {
          const task = new taskpool.Task(writeSSHInput, this.sessionId, 'printf "\\e[?2004l"\n');
          await taskpool.execute(task);
        } catch (e) {
          hilog.warn(LOG_DOMAIN, LOG_TAG, 'Failed to disable bracketed paste mode');
        }
      }, 500);
      
      // 在后台线程轮询读取输出
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
      this.startKeepaliveWatchdog();
      
    } catch (error) {
      // 捕获异常，判断错误类型
      const err = error as Error;
      const errorMsg = err.message || String(error);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'SSH connection exception: %{public}s', errorMsg);
      
      // 判断是否为网络问题
      const isNetworkIssue = this.isNetworkError(d.host) || 
        errorMsg.includes('network') || 
        errorMsg.includes('网络') ||
        errorMsg.includes('timeout') ||
        errorMsg.includes('超时') ||
        errorMsg.includes('unreachable') ||
        errorMsg.includes('不可达');
      
      const displayMsg = isNetworkIssue ? '网络故障，无法连接服务器' : `SSH连接失败: ${errorMsg}`;
      promptAction.showToast({ message: displayMsg });
      this.stopKeepaliveWatchdog();
      // 延迟返回避免应用退出
      setTimeout(() => {
        router.back();
      }, 1000);
    }
  }

  // 简单检测网络问题（可以后续优化）
  private isNetworkError(host: string): boolean {
    // 这里可以添加更复杂的网络检测逻辑
    // 目前简单地返回false，依赖sessionId判断
    return false;
  }

  private startKeepaliveWatchdog(): void {
    this.stopKeepaliveWatchdog();
    const intervalSeconds = SettingsStore.sessionKeepaliveInterval;
    if (intervalSeconds <= 0 || this.sessionId <= 0) {
      return;
    }
    const intervalMs = Math.max(5, intervalSeconds) * 1000;
    this.keepaliveTimerId = setInterval(() => {
      this.invokeKeepalive();
    }, intervalMs) as number;
  }

  private stopKeepaliveWatchdog(): void {
    if (this.keepaliveTimerId > 0) {
      clearInterval(this.keepaliveTimerId);
      this.keepaliveTimerId = -1;
    }
  }

  private invokeKeepalive(): void {
    if (this.sessionId <= 0) {
      return;
    }
    try {
      const ok = SSHEngine.sendKeepalive(this.sessionId);
      if (ok) {
        this.keepaliveFailures = 0;
      } else {
        this.keepaliveFailures += 1;
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'Keepalive failed count=%{public}d', this.keepaliveFailures);
        if (this.keepaliveFailures >= SettingsStore.sessionKeepaliveAttempts) {
          this.stopKeepaliveWatchdog();
          promptAction.showToast({ message: '会话保活失败，连接已断开' });
          if (this.sessionId > 0) {
            SSHEngine.closeSession(this.sessionId);
            this.sessionId = -1;
          }
          setTimeout(() => {
            router.back();
          }, 1000);
        }
      }
    } catch (err) {
      const errorMsg: string = err instanceof Error ? err.message : String(err);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Keepalive exception: %{public}s', errorMsg);
    }
  }

  aboutToDisappear(): void {
    if (this.timerId > 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.stopKeepaliveWatchdog();
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

  private async sendQuickKey(label: string, sequence: string): Promise<void> {
    if (this.sessionId <= 0) {
      promptAction.showToast({ message: '连接未建立，无法发送快捷键' });
      return;
    }
    try {
      const task = new taskpool.Task(writeSSHInput, this.sessionId, sequence);
      await taskpool.execute(task);
      promptAction.showToast({ message: `已发送 ${label}` });
    } catch (e) {
      const msg: string = e instanceof Error ? e.message : String(e);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Send quick key failed: %{public}s', msg);
      promptAction.showToast({ message: `发送失败: ${msg}` });
    } finally {
      this.showKeyMenu = false;
    }
  }

  private async copyOutput(): Promise<void> {
    const text = this.lines.join('\n');
    if (!text) {
      promptAction.showToast({ message: '暂无可复制内容' });
      return;
    }
    try {
      const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      promptAction.showToast({ message: '终端输出已复制' });
    } catch (e) {
      const msg: string = e instanceof Error ? e.message : String(e);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Copy output failed: %{public}s', msg);
      promptAction.showToast({ message: `复制失败: ${msg}` });
    } finally {
      this.showKeyMenu = false;
    }
  }

  private async pasteToInput(): Promise<void> {
    try {
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      const data: pasteboard.PasteData = await systemPasteboard.getData();
      const text: string = data.getPrimaryText ? data.getPrimaryText() : '';
      if (!text) {
        promptAction.showToast({ message: '剪贴板为空' });
        return;
      }
      this.cmd += text;
      promptAction.showToast({ message: '已粘贴到输入框' });
    } catch (e) {
      const msg: string = e instanceof Error ? e.message : String(e);
      hilog.error(LOG_DOMAIN, LOG_TAG, 'Paste failed: %{public}s', msg);
      promptAction.showToast({ message: `粘贴失败: ${msg}` });
    } finally {
      this.showKeyMenu = false;
    }
  }

  build() {
    Column() {
      // 顶部标题栏（返回 + 快捷键列表）
      Stack() {
        Row() {
          Text('<')
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .width(40)
            .height(40)
            .textAlign(TextAlign.Center)
            .onClick((): void => {
              router.replaceUrl({ url: 'pages/Index' });
            })
          
          Text('终端')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 4 })
          Blank().layoutWeight(1)
          Button('常用按键')
            .type(ButtonType.Normal)
            .height(32)
            .fontSize(14)
            .onClick((): void => { this.showKeyMenu = !this.showKeyMenu; })
        }
        .height(56)
        .width('100%')
        .padding({ left: 8, right: 16 })

        if (this.showKeyMenu) {
          Column({ space: 8 }) {
            ForEach(this.quickKeys, (item: QuickKey) => {
              Button(item.label)
                .type(ButtonType.Normal)
                .onClick((): void => { this.sendQuickKey(item.label, item.sequence); });
            }, (item: QuickKey) => item.label)
            Button('复制输出')
              .type(ButtonType.Normal)
              .onClick((): void => { this.copyOutput(); })
            Button('粘贴到输入')
              .type(ButtonType.Normal)
              .onClick((): void => { this.pasteToInput(); })
          }
          .padding(12)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(12)
          .shadow({ radius: 6, color: '#33000000', offsetX: 0, offsetY: 2 })
          .position({ x: '70%', y: 56 })
        }
      }

      // 输出区
      Scroll(this.scroller) {
        Column({ space: 4 }) {
          ForEach(this.lines, (line: string, idx: number) => {
            Text(line)
              .fontSize(this.terminalFontSize)
              .fontFamily(this.terminalFontFamily)
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
      Row({ space: 12 }) {
        TextInput({ placeholder: '输入命令', text: this.cmd })
          .onChange((v: string): void => { this.cmd = v })
          .onSubmit((): void => { this.run(); })
          .fontSize(this.terminalFontSize)
          .fontFamily(this.terminalFontFamily)
          .layoutWeight(1)
          .height(48)
          .borderRadius(24)
        
        Button() {
          Row({ space: 6 }) {
            Text('执行')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
        }
        .type(ButtonType.Normal)
        .height(48)
        .padding({ left: 20, right: 20 })
        .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
        .borderRadius(24)
        .enabled(this.cmd.length > 0)
        .opacity(this.cmd.length > 0 ? 1 : 0.5)
        .onClick((): void => { this.run(); })
      }
      .padding({ left: 16, right: 16, top: 12, bottom: 16 })
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    }
    .width('100%')
    .height('100%')
  }
}
