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
function runPortCheck(host: string, port: number, timeout: number): string {
  return kessh.testPort(host, port, timeout);
}

@Component
export struct ToolsPage {
  @State pingHost: string = '';
  @State pingCount: string = '4';
  @State pingResult: string = '';
  @State pingLoading: boolean = false;

  @State subnetIp: string = '';
  @State subnetMask: string = '24';
  @State subnetResult: string = '';

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

  private clearSubnetResult(): void {
    this.subnetResult = '';
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

  private calculateSubnet(): void {
    const ip = this.normalizeHost(this.subnetIp);
    if (!ip) {
      promptAction.showToast({ message: '请输入IP地址' });
      return;
    }
    
    // 验证IP格式
    const ipParts = ip.split('.');
    if (ipParts.length !== 4 || !ipParts.every((part) => {
      const num = parseInt(part);
      return !isNaN(num) && num >= 0 && num <= 255;
    })) {
      promptAction.showToast({ message: 'IP地址格式错误' });
      return;
    }
    
    let maskBits = parseInt(this.subnetMask) || 24;
    if (maskBits < 0) maskBits = 0;
    if (maskBits > 32) maskBits = 32;
    
    try {
      // 计算子网掩码
      const mask = (0xFFFFFFFF << (32 - maskBits)) >>> 0;
      const maskOctets = [
        (mask >>> 24) & 0xFF,
        (mask >>> 16) & 0xFF,
        (mask >>> 8) & 0xFF,
        mask & 0xFF
      ];
      const maskStr = maskOctets.join('.');
      
      // 计算网络地址
      const ipNum = ipParts.reduce((acc, octet) => (acc << 8) + parseInt(octet), 0) >>> 0;
      const networkNum = (ipNum & mask) >>> 0;
      const networkOctets = [
        (networkNum >>> 24) & 0xFF,
        (networkNum >>> 16) & 0xFF,
        (networkNum >>> 8) & 0xFF,
        networkNum & 0xFF
      ];
      const networkStr = networkOctets.join('.');
      
      // 计算广播地址
      const broadcastNum = (networkNum | (~mask & 0xFFFFFFFF)) >>> 0;
      const broadcastOctets = [
        (broadcastNum >>> 24) & 0xFF,
        (broadcastNum >>> 16) & 0xFF,
        (broadcastNum >>> 8) & 0xFF,
        broadcastNum & 0xFF
      ];
      const broadcastStr = broadcastOctets.join('.');
      
      // 计算主机范围
      const firstHostNum = networkNum + 1;
      const lastHostNum = broadcastNum - 1;
      const firstHostOctets = [
        (firstHostNum >>> 24) & 0xFF,
        (firstHostNum >>> 16) & 0xFF,
        (firstHostNum >>> 8) & 0xFF,
        firstHostNum & 0xFF
      ];
      const lastHostOctets = [
        (lastHostNum >>> 24) & 0xFF,
        (lastHostNum >>> 16) & 0xFF,
        (lastHostNum >>> 8) & 0xFF,
        lastHostNum & 0xFF
      ];
      const firstHostStr = firstHostOctets.join('.');
      const lastHostStr = lastHostOctets.join('.');
      
      // 计算可用主机数
      const totalHosts = Math.pow(2, 32 - maskBits);
      const usableHosts = maskBits === 32 ? 1 : (maskBits === 31 ? 2 : totalHosts - 2);
      
      // 判断IP类别
      const firstOctet = parseInt(ipParts[0]);
      let ipClass = '';
      if (firstOctet >= 1 && firstOctet <= 126) ipClass = 'A类';
      else if (firstOctet >= 128 && firstOctet <= 191) ipClass = 'B类';
      else if (firstOctet >= 192 && firstOctet <= 223) ipClass = 'C类';
      else if (firstOctet >= 224 && firstOctet <= 239) ipClass = 'D类(组播)';
      else if (firstOctet >= 240 && firstOctet <= 255) ipClass = 'E类(保留)';
      
      // 判断是否为私有地址
      let isPrivate = false;
      if (firstOctet === 10) isPrivate = true;
      else if (firstOctet === 172 && parseInt(ipParts[1]) >= 16 && parseInt(ipParts[1]) <= 31) isPrivate = true;
      else if (firstOctet === 192 && parseInt(ipParts[1]) === 168) isPrivate = true;
      
      this.subnetResult = `IP地址: ${ip}\n` +
        `子网掩码: ${maskStr} (/${maskBits})\n` +
        `网络地址: ${networkStr}\n` +
        `广播地址: ${broadcastStr}\n` +
        `主机范围: ${firstHostStr} - ${lastHostStr}\n` +
        `总IP数: ${totalHosts}\n` +
        `可用主机数: ${usableHosts}\n` +
        `IP类别: ${ipClass}\n` +
        `地址类型: ${isPrivate ? '私有地址' : '公网地址'}`;
    } catch (err) {
      const error = err as Error;
      this.subnetResult = `计算失败: ${error.message}`;
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
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      
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
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .fontColor(Color.White)
          .borderRadius(24)
          .enabled(!this.pingLoading)
          .onClick((): void => { this.handlePing(); });
      }
      
      if (this.pingResult) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('输出')
              .fontSize(14)
              .fontWeight(FontWeight.Medium);
            Blank().layoutWeight(1);
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
          Text(this.pingResult)
            .fontSize(14)
            .textAlign(TextAlign.Start)
            .fontFamily('monospace')
            .maxLines(10)
            .width('100%');
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(12);
      }
    }
    .padding(16)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .borderRadius(16)
    .width('100%');
  }

  @Builder
  subnetCalcCard() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('子网掩码计算器')
          .fontSize(20)
          .fontWeight(FontWeight.Medium);
        Text('计算IP地址的子网信息')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'));
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      
      TextInput({ placeholder: 'IP地址 (例: 192.168.1.1)', text: this.subnetIp })
        .onChange((value: string): void => { this.subnetIp = value; });
      Row({ space: 12 }) {
        TextInput({ placeholder: '掩码位数(0-32)', text: this.subnetMask })
          .type(InputType.Number)
          .layoutWeight(1)
          .onChange((value: string): void => { this.subnetMask = value; });
        Button('计算')
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .fontColor(Color.White)
          .borderRadius(24)
          .onClick((): void => { this.calculateSubnet(); });
      }
      
      if (this.subnetResult) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('计算结果')
              .fontSize(14)
              .fontWeight(FontWeight.Medium);
            Blank().layoutWeight(1);
            Button('复制')
              .type(ButtonType.Capsule)
              .height(28)
              .fontSize(12)
              .onClick((): void => { void this.copyResult(this.subnetResult, '子网计算'); });
            Button('清空')
              .type(ButtonType.Capsule)
              .height(28)
              .fontSize(12)
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
              .onClick((): void => { this.clearSubnetResult(); });
          }
          Text(this.subnetResult)
            .fontSize(14)
            .textAlign(TextAlign.Start)
            .fontFamily('monospace')
            .maxLines(15)
            .width('100%');
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(12);
      }
    }
    .padding(16)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .borderRadius(16)
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
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .fontColor(Color.White)
          .borderRadius(24)
          .onClick((): void => { this.handleBase64Encode(); });
        Button('← 解码')
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
          .fontColor(Color.White)
          .borderRadius(24)
          .onClick((): void => { this.handleBase64Decode(); });
      }

      Text(this.base64Status || '在本地完成转换，不会上传数据')
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'));
    }
    .padding(16)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .borderRadius(16)
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
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      
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
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
        .fontColor(Color.White)
        .borderRadius(24)
        .enabled(!this.portLoading)
        .onClick((): void => { this.handlePortTest(); });
      
      if (this.portResult) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('输出')
              .fontSize(14)
              .fontWeight(FontWeight.Medium);
            Blank().layoutWeight(1);
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
          Text(this.portResult)
            .fontSize(14)
            .textAlign(TextAlign.Start)
            .fontFamily('monospace')
            .maxLines(10)
            .width('100%');
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(12);
      }
    }
    .padding(16)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .borderRadius(16)
    .width('100%');
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        this.pingToolCard();
        this.subnetCalcCard();
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
