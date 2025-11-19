import { router, promptAction } from '@kit.ArkUI';
import util from '@ohos.util';

const base64Helper: util.Base64Helper = new util.Base64Helper();
const textEncoder: util.TextEncoder = util.TextEncoder.create();
const textDecoder: util.TextDecoder = util.TextDecoder.create();

@Entry
@Component
struct Base64Tool {
  @State base64Plain: string = '';
  @State base64Encoded: string = '';
  @State base64Status: string = '';

  private formatTimestamp(): string {
    const date = new Date();
    const pad = (value: number): string => value.toString().padStart(2, '0');
    return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
  }

  private handleBase64Encode(): void {
    if (!this.base64Plain) {
      promptAction.showToast({ message: '请输入待编码文本' });
      return;
    }
    try {
      const encoded = base64Helper.encodeToStringSync(textEncoder.encodeInto(this.base64Plain));
      this.base64Encoded = encoded;
      this.base64Status = `[${this.formatTimestamp()}] 编码成功`;
      promptAction.showToast({ message: '编码成功' });
    } catch (err) {
      const error = err as Error;
      this.base64Status = `[${this.formatTimestamp()}] 编码失败: ${error.message}`;
      promptAction.showToast({ message: `编码失败: ${error.message}` });
    }
  }

  private handleBase64Decode(): void {
    if (!this.base64Encoded) {
      promptAction.showToast({ message: '请输入待解码文本' });
      return;
    }
    try {
      const decoded = base64Helper.decodeSync(this.base64Encoded);
      this.base64Plain = textDecoder.decodeToString(decoded);
      this.base64Status = `[${this.formatTimestamp()}] 解码成功`;
      promptAction.showToast({ message: '解码成功' });
    } catch (err) {
      const error = err as Error;
      this.base64Status = `[${this.formatTimestamp()}] 解码失败: ${error.message}`;
      promptAction.showToast({ message: `解码失败: ${error.message}` });
    }
  }

  private clearAll(): void {
    this.base64Plain = '';
    this.base64Encoded = '';
    this.base64Status = '';
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
        
        Text('Base64 编解码')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 4 })
        Blank().layoutWeight(1)
        
        Button('清空')
          .type(ButtonType.Capsule)
          .height(32)
          .fontSize(14)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .onClick((): void => { this.clearAll(); })
      }
      .height(56)
      .width('100%')
      .padding({ left: 8, right: 16 })

      Scroll() {
        Column({ space: 16 }) {
          // 工具说明卡片
          Column({ space: 8 }) {
            Text('🔐 Base64 转换工具')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text('在本地完成字符串的编码和解码，所有数据仅在设备上处理，不会上传到服务器')
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          // 原文输入卡片
          Column({ space: 12 }) {
            Row() {
              Text('原文')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Blank().layoutWeight(1)
              Text(`${this.base64Plain.length} 字符`)
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
            .width('100%')
            
            TextArea({ placeholder: '输入待编码的文本内容...', text: this.base64Plain })
              .height(120)
              .onChange((value: string): void => { this.base64Plain = value; })
            
            Button('编码 →')
              .type(ButtonType.Normal)
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
              .fontColor(Color.White)
              .borderRadius(24)
              .onClick((): void => { this.handleBase64Encode(); })
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(16)

          // Base64 输入卡片
          Column({ space: 12 }) {
            Row() {
              Text('Base64 文本')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Blank().layoutWeight(1)
              Text(`${this.base64Encoded.length} 字符`)
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
            .width('100%')
            
            TextArea({ placeholder: '输入待解码的 Base64 文本...', text: this.base64Encoded })
              .height(120)
              .onChange((value: string): void => { this.base64Encoded = value; })
            
            Button('← 解码')
              .type(ButtonType.Normal)
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
              .fontColor(Color.White)
              .borderRadius(24)
              .onClick((): void => { this.handleBase64Decode(); })
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(16)

          // 状态提示
          if (this.base64Status) {
            Text(this.base64Status)
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .textAlign(TextAlign.Center)
              .width('100%')
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
