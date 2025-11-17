import { promptAction } from '@kit.ArkUI';
import { taskpool } from '@kit.ArkTS';
import { pasteboard } from '@kit.BasicServicesKit';
import util from '@ohos.util';
import kessh from 'libkessh.so';

const base64Helper: util.Base64Helper = new util.Base64Helper();
const textEncoder: util.TextEncoder = util.TextEncoder.create();
const textDecoder: util.TextDecoder = util.TextDecoder.create();

@Concurrent
function runPing(host: string, count: number): string {
  return kessh.pingHost(host, count);
}

@Concurrent
function runTrace(host: string, maxHops: number): string {
  return kessh.traceRoute(host, maxHops);
}

@Concurrent
function runPortCheck(host: string, port: number, timeout: number): string {
  return kessh.testPort(host, port, timeout);
}

@Component
export struct ToolsPage {
  @State pingHost: string = '';
  @State pingCount: string = '4';
  @State pingResult: string = '';
  @State pingLoading: boolean = false;

  @State traceHost: string = '';
  @State traceMaxHop: string = '20';
  @State traceResult: string = '';
  @State traceLoading: boolean = false;

  @State base64Plain: string = '';
  @State base64Encoded: string = '';
  @State base64Status: string = '';

  @State portHost: string = '';
  @State portNumber: string = '22';
  @State portTimeout: string = '3000';
  @State portResult: string = '';
  @State portLoading: boolean = false;

  private formatTimestamp(): string {
    const date = new Date();
    const pad = (value: number): string => value.toString().padStart(2, '0');
    return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
  }

  private async copyResult(result: string, label: string): Promise<void> {
    if (!result) {
      promptAction.showToast({ message: `暂无可复制的${label}结果` });
      return;
    }
    try {
      const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, result);
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      promptAction.showToast({ message: `${label}结果已复制` });
    } catch (err) {
      const error = err as Error;
      promptAction.showToast({ message: `复制失败: ${error.message}` });
    }
  }

  private clearPingResult(): void {
    this.pingResult = '';
  }

  private clearTraceResult(): void {
    this.traceResult = '';
  }

  private clearPortResult(): void {
    this.portResult = '';
  }

  private normalizeHost(input: string): string {
    return (input || '').trim();
  }

  private async handlePing(): Promise<void> {
    const host = this.normalizeHost(this.pingHost);
    if (!host) {
      promptAction.showToast({ message: '请输入需要 Ping 的主机' });
      return;
    }
    let count = parseInt(this.pingCount) || 4;
    if (count <= 0) {
      count = 4;
    }
    if (count > 10) {
      count = 10;
    }
    this.pingLoading = true;
    this.pingResult = `[${this.formatTimestamp()}] 正在测试...`;
    try {
      const task = new taskpool.Task(runPing, host, count);
      const output = await taskpool.execute(task) as string;
      this.pingResult = `[${this.formatTimestamp()}]\n${output}`;
    } catch (err) {
      const error = err as Error;
      this.pingResult = `[${this.formatTimestamp()}] Ping 执行失败: ${error.message}`;
    } finally {
      this.pingLoading = false;
    }
  }

  private async handleTrace(): Promise<void> {
    const host = this.normalizeHost(this.traceHost);
    if (!host) {
      promptAction.showToast({ message: '请输入需要 Tracert 的主机' });
      return;
    }
    let maxHops = parseInt(this.traceMaxHop) || 20;
    if (maxHops <= 0) {
      maxHops = 20;
    }
    if (maxHops > 64) {
      maxHops = 64;
    }
    this.traceLoading = true;
    this.traceResult = `[${this.formatTimestamp()}] 正在探测路径...`;
    try {
      const task = new taskpool.Task(runTrace, host, maxHops);
      const output = await taskpool.execute(task) as string;
      this.traceResult = `[${this.formatTimestamp()}]\n${output}`;
    } catch (err) {
      const error = err as Error;
      this.traceResult = `[${this.formatTimestamp()}] Tracert 执行失败: ${error.message}`;
    } finally {
      this.traceLoading = false;
    }
  }

  private handleBase64Encode(): void {
    try {
      const encoded = base64Helper.encodeToStringSync(textEncoder.encodeInto(this.base64Plain));
      this.base64Encoded = encoded;
      this.base64Status = `[${this.formatTimestamp()}] 编码成功`;
    } catch (err) {
      const error = err as Error;
      this.base64Status = `[${this.formatTimestamp()}] 编码失败: ${error.message}`;
    }
  }

  private handleBase64Decode(): void {
    try {
      const decoded = base64Helper.decodeSync(this.base64Encoded);
      this.base64Plain = textDecoder.decodeToString(decoded);
      this.base64Status = `[${this.formatTimestamp()}] 解码成功`;
    } catch (err) {
      const error = err as Error;
      this.base64Status = `[${this.formatTimestamp()}] 解码失败: ${error.message}`;
    }
  }

  private async handlePortTest(): Promise<void> {
    const host = this.normalizeHost(this.portHost);
    const port = parseInt(this.portNumber);
    if (!host || !port || port <= 0 || port > 65535) {
      promptAction.showToast({ message: '请填写有效的主机与端口' });
      return;
    }
    let timeout = parseInt(this.portTimeout);
    if (!timeout || timeout < 1000) {
      timeout = 1000;
    }
    if (timeout > 15000) {
      timeout = 15000;
    }
    this.portLoading = true;
    this.portResult = `[${this.formatTimestamp()}] 正在连接...`;
    try {
      const task = new taskpool.Task(runPortCheck, host, port, timeout);
      const output = await taskpool.execute(task) as string;
      this.portResult = `[${this.formatTimestamp()}]\n${output}`;
    } catch (err) {
      const error = err as Error;
      this.portResult = `[${this.formatTimestamp()}] 端口不可用: ${error.message}`;
    } finally {
      this.portLoading = false;
    }
  }

  @Builder
  pingToolCard() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('Ping 工具')
          .fontSize(20)
          .fontWeight(FontWeight.Medium);
        Text('快速检测主机连通性与延迟')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'));
      }
      TextInput({ placeholder: '主机或IP地址', text: this.pingHost })
        .onChange((value: string): void => { this.pingHost = value; });
      Row({ space: 12 }) {
        TextInput({ placeholder: '次数(1-10)', text: this.pingCount })
          .type(InputType.Number)
          .layoutWeight(1)
          .onChange((value: string): void => { this.pingCount = value; });
        Button(this.pingLoading ? '测试中...' : '开始 Ping')
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(40)
          .enabled(!this.pingLoading)
          .onClick((): void => { this.handlePing(); });
      }
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text('输出')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));
          Blank().layoutWeight(1);
          if (this.pingResult) {
            Button('复制')
              .type(ButtonType.Capsule)
              .height(28)
              .fontSize(12)
              .onClick((): void => { void this.copyResult(this.pingResult, 'Ping'); });
            Button('清空')
              .type(ButtonType.Capsule)
              .height(28)
              .fontSize(12)
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
              .onClick((): void => { this.clearPingResult(); });
          }
        }
        Text(this.pingResult || '暂无结果')
          .fontSize(14)
          .textAlign(TextAlign.Start)
          .fontFamily('monospace')
          .maxLines(10);
      }
      .width('100%');
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: 4 })
    .width('100%');
  }

  @Builder
  traceToolCard() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('Tracert 工具')
          .fontSize(20)
          .fontWeight(FontWeight.Medium);
        Text('查看到目标主机的路由路径')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'));
      }
      TextInput({ placeholder: '主机或IP地址', text: this.traceHost })
        .onChange((value: string): void => { this.traceHost = value; });
      Row({ space: 12 }) {
        TextInput({ placeholder: '最大跳数(1-64)', text: this.traceMaxHop })
          .type(InputType.Number)
          .layoutWeight(1)
          .onChange((value: string): void => { this.traceMaxHop = value; });
        Button(this.traceLoading ? '探测中...' : '开始 Tracert')
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(40)
          .enabled(!this.traceLoading)
          .onClick((): void => { this.handleTrace(); });
      }
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text('输出')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));
          Blank().layoutWeight(1);
          if (this.traceResult) {
            Button('复制')
              .type(ButtonType.Capsule)
              .height(28)
              .fontSize(12)
              .onClick((): void => { void this.copyResult(this.traceResult, 'Tracert'); });
            Button('清空')
              .type(ButtonType.Capsule)
              .height(28)
              .fontSize(12)
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
              .onClick((): void => { this.clearTraceResult(); });
          }
        }
        Text(this.traceResult || '暂无结果')
          .fontSize(14)
          .textAlign(TextAlign.Start)
          .fontFamily('monospace')
          .maxLines(10);
      }
      .width('100%');
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: 4 })
    .width('100%');
  }

  @Builder
  base64ToolCard() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('Base64 编解码')
          .fontSize(20)
          .fontWeight(FontWeight.Medium);
        Text('在本地完成字符串的编码/解码')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'));
      }
      Text('原文')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'));
      TextArea({ placeholder: '输入待编码文本', text: this.base64Plain })
        .height(80)
        .borderRadius(12)
        .onChange((value: string): void => { this.base64Plain = value; });

      Text('Base64 文本')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ top: 8 });
      TextArea({ placeholder: '输入待解码文本', text: this.base64Encoded })
        .height(80)
        .borderRadius(12)
        .onChange((value: string): void => { this.base64Encoded = value; });

      Row({ space: 12 }) {
        Button('编码 →')
          .layoutWeight(1)
          .height(36)
          .onClick((): void => { this.handleBase64Encode(); });
        Button('← 解码')
          .layoutWeight(1)
          .height(36)
          .onClick((): void => { this.handleBase64Decode(); });
      }

      Text(this.base64Status || '在本地完成转换，不会上传数据')
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'));
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: 4 })
    .width('100%');
  }

  @Builder
  portTestToolCard() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('端口测试')
          .fontSize(20)
          .fontWeight(FontWeight.Medium);
        Text('验证指定主机端口是否开放')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'));
      }
      TextInput({ placeholder: '主机或IP地址', text: this.portHost })
        .onChange((value: string): void => { this.portHost = value; });
      Row({ space: 12 }) {
        TextInput({ placeholder: '端口', text: this.portNumber })
          .type(InputType.Number)
          .layoutWeight(1)
          .onChange((value: string): void => { this.portNumber = value; });
        TextInput({ placeholder: '超时(ms)', text: this.portTimeout })
          .type(InputType.Number)
          .layoutWeight(1)
          .onChange((value: string): void => { this.portTimeout = value; });
      }
      Button(this.portLoading ? '测试中...' : '开始测试')
        .type(ButtonType.Normal)
        .height(40)
        .enabled(!this.portLoading)
        .onClick((): void => { this.handlePortTest(); });
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text('输出')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));
          Blank().layoutWeight(1);
          if (this.portResult) {
            Button('复制')
              .type(ButtonType.Capsule)
              .height(28)
              .fontSize(12)
              .onClick((): void => { void this.copyResult(this.portResult, '端口测试'); });
            Button('清空')
              .type(ButtonType.Capsule)
              .height(28)
              .fontSize(12)
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
              .onClick((): void => { this.clearPortResult(); });
          }
        }
        Text(this.portResult || '暂无结果')
          .fontSize(14)
          .textAlign(TextAlign.Start)
          .fontFamily('monospace')
          .maxLines(10);
      }
      .width('100%');
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: 4 })
    .width('100%');
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        this.pingToolCard();
        this.traceToolCard();
        this.base64ToolCard();
        this.portTestToolCard();
      }
      .padding(16)
      .width('100%');
    }
    .scrollBar(BarState.Off)
    .layoutWeight(1)
    .width('100%');
  }
}
