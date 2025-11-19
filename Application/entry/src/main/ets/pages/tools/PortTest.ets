import { router, promptAction } from '@kit.ArkUI';
import { taskpool } from '@kit.ArkTS';
import { pasteboard } from '@kit.BasicServicesKit';
import kessh from 'libkessh.so';

@Concurrent
function runPortCheck(host: string, port: number, timeout: number): string {
  return kessh.testPort(host, port, timeout);
}

@Entry
@Component
struct PortTest {
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

  private async copyResult(): Promise<void> {
    if (!this.portResult) {
      promptAction.showToast({ message: '暂无可复制的结果' });
      return;
    }
    try {
      const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.portResult);
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      promptAction.showToast({ message: '结果已复制' });
    } catch (err) {
      const error = err as Error;
      promptAction.showToast({ message: `复制失败: ${error.message}` });
    }
  }

  private clearResult(): void {
    this.portResult = '';
  }

  private normalizeHost(input: string): string {
    return (input || '').trim();
  }

  private async handlePortTest(): Promise<void> {
    const host = this.normalizeHost(this.portHost);
    const port = parseInt(this.portNumber);
    if (!host || !port || port <= 0 || port > 65535) {
      promptAction.showToast({ message: '请填写有效的主机与端口' });
      return;
    }
    let timeout = parseInt(this.portTimeout);
    if (!timeout || timeout < 1000) timeout = 1000;
    if (timeout > 15000) timeout = 15000;
    
    this.portLoading = true;
    this.portResult = `[${this.formatTimestamp()}] 正在连接 ${host}:${port}...`;
    
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
        
        Text('端口测试')
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
            Text('🔌 端口可用性检测')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text('验证指定主机的端口是否开放，常用于检测SSH(22)、HTTP(80)、HTTPS(443)等服务')
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
            TextInput({ placeholder: '主机或IP地址', text: this.portHost })
              .onChange((value: string): void => { this.portHost = value; })
            
            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text('端口号')
                  .fontSize(14)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .width('100%')
                TextInput({ placeholder: '1-65535', text: this.portNumber })
                  .type(InputType.Number)
                  .onChange((value: string): void => { this.portNumber = value; })
              }
              .layoutWeight(1)
              
              Column({ space: 4 }) {
                Text('超时(ms)')
                  .fontSize(14)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .width('100%')
                TextInput({ placeholder: '1000-15000', text: this.portTimeout })
                  .type(InputType.Number)
                  .onChange((value: string): void => { this.portTimeout = value; })
              }
              .layoutWeight(1)
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
              .onClick((): void => { this.handlePortTest(); })
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(16)

          // 常用端口参考
          Column({ space: 8 }) {
            Text('常用端口参考')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            
            Column({ space: 4 }) {
              Text('• SSH: 22  •  HTTP: 80  •  HTTPS: 443')
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              Text('• FTP: 21  •  MySQL: 3306  •  Redis: 6379')
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)

          // 结果显示区域
          if (this.portResult) {
            Column({ space: 12 }) {
              Row({ space: 8 }) {
                Text('测试结果')
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
              
              Text(this.portResult)
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
