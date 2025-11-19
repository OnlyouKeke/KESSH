import { router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';

@Entry
@Component
struct SubnetCalc {
  @State subnetIp: string = '';
  @State subnetMask: string = '24';
  @State subnetResult: string = '';

  private async copyResult(): Promise<void> {
    if (!this.subnetResult) {
      promptAction.showToast({ message: '暂无可复制的结果' });
      return;
    }
    try {
      const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.subnetResult);
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      promptAction.showToast({ message: '结果已复制' });
    } catch (err) {
      const error = err as Error;
      promptAction.showToast({ message: `复制失败: ${error.message}` });
    }
  }

  private clearResult(): void {
    this.subnetResult = '';
  }

  private normalizeHost(input: string): string {
    return (input || '').trim();
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

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('<')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick((): void => { router.back(); })
        
        Text('子网掩码计算器')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 4 })
        Blank().layoutWeight(1)
      }
      .height(56)
      .width('100%')
      .padding({ left: 8, right: 16 })

      Scroll() {
        Column({ space: 16 }) {
          // 工具说明卡片
          Column({ space: 8 }) {
            Text('🔢 子网信息计算')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text('根据IP地址和子网掩码位数，自动计算网络地址、广播地址、主机范围等信息')
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          // 输入表单卡片
          Column({ space: 12 }) {
            TextInput({ placeholder: 'IP地址（例：192.168.1.100）', text: this.subnetIp })
              .onChange((value: string): void => { this.subnetIp = value; })
            
            Row({ space: 12 }) {
              TextInput({ placeholder: '掩码位数(0-32)', text: this.subnetMask })
                .type(InputType.Number)
                .layoutWeight(1)
                .onChange((value: string): void => { this.subnetMask = value; })
              
              Button('开始计算')
                .type(ButtonType.Normal)
                .layoutWeight(1)
                .height(48)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
                .fontColor(Color.White)
                .borderRadius(24)
                .onClick((): void => { this.calculateSubnet(); })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(16)

          // 结果显示区域
          if (this.subnetResult) {
            Column({ space: 12 }) {
              Row({ space: 8 }) {
                Text('计算结果')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                Blank().layoutWeight(1)
                Button('复制')
                  .type(ButtonType.Capsule)
                  .height(32)
                  .fontSize(14)
                  .onClick((): void => { void this.copyResult(); })
                Button('清空')
                  .type(ButtonType.Capsule)
                  .height(32)
                  .fontSize(14)
                  .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
                  .onClick((): void => { this.clearResult(); })
              }
              
              Text(this.subnetResult)
                .fontSize(14)
                .fontFamily('monospace')
                .textAlign(TextAlign.Start)
                .width('100%')
                .padding(12)
                .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
                .borderRadius(12)
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .borderRadius(16)
          }
        }
        .padding(16)
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
  }
}
