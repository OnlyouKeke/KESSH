import { promptAction, CopyOptions } from '@kit.ArkUI';
import { taskpool } from '@kit.ArkTS';
import socket from '@ohos.net.socket';
import util from '@ohos.util';
import clipboard from '@ohos.miscservices.clipboard';
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
      const systemClipboard = clipboard.getSystemClipboard();
      await systemClipboard.setData({ textData: result });
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

  private getAddressFamily(host: string): socket.NetAddressFamily {
    return host.includes(':') ? socket.NetAddressFamily.IPV6 : socket.NetAddressFamily.IPV4;
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
    const tcpSocket = socket.constructTCPSocketInstance();
    this.portLoading = true;
    this.portResult = `[${this.formatTimestamp()}] 正在连接...`;
    try {
      const start = new Date().getTime();
      await tcpSocket.connect({
        address: {
          address: host,
          port: port,
          family: this.getAddressFamily(host)
        },
        timeout: timeout
      });
      const duration = new Date().getTime() - start;
      this.portResult = `[${this.formatTimestamp()}] 端口开放，响应时间 ${duration} ms`;
    } catch (err) {
      const error = err as Error;
      this.portResult = `[${this.formatTimestamp()}] 端口不可用: ${error.message}`;
    } finally {
      try {
        tcpSocket.close();
      } catch (_) {}
      this.portLoading = false;
    }
  }

  @Builder
  private toolCard(title: string, description: string, content: () => void) {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(20)
          .fontWeight(FontWeight.Medium);
        Text(description)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'));
      }
      content();
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: 4 })
    .width('100%');
  }

  @Builder
  private buildResultBlock(label: string, result: string, onClear: () => void) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('输出')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'));
        Blank().layoutWeight(1);
        if (result) {
          Button('复制')
            .type(ButtonType.Capsule)
            .height(28)
            .fontSize(12)
            .onClick(() => { this.copyResult(result, label); });
          Button('清空')
            .type(ButtonType.Capsule)
            .height(28)
            .fontSize(12)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .onClick(() => { onClear(); });
        }
      }
      Text(result || '暂无结果')
        .fontSize(14)
        .textAlign(TextAlign.Start)
        .fontFamily('monospace')
        .maxLines(10)
        .copyOption(CopyOptions.InApp);
    }
    .width('100%');
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        this.toolCard('Ping 工具', '快速检测主机连通性与延迟', () => {
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
              .onClick(() => { this.handlePing(); });
          }
          this.buildResultBlock('Ping', this.pingResult, () => { this.clearPingResult(); });
        });

        this.toolCard('Tracert 工具', '查看到目标主机的路由路径', () => {
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
              .onClick(() => { this.handleTrace(); });
          }
          this.buildResultBlock('Tracert', this.traceResult, () => { this.clearTraceResult(); });
        });

        this.toolCard('Base64 编解码', '在本地完成字符串的编码/解码', () => {
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
              .onClick(() => { this.handleBase64Encode(); });
            Button('← 解码')
              .layoutWeight(1)
              .height(36)
              .onClick(() => { this.handleBase64Decode(); });
          }

          Text(this.base64Status || '在本地完成转换，不会上传数据')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'));
        });

        this.toolCard('端口测试', '验证指定主机端口是否开放', () => {
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
            .onClick(() => { this.handlePortTest(); });
          this.buildResultBlock('端口测试', this.portResult, () => { this.clearPortResult(); });
        });
      }
      .padding(16)
      .width('100%');
    }
    .scrollBar(BarState.Off)
    .layoutWeight(1)
    .width('100%');
  }
}
