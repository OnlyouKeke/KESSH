import { router, promptAction } from '@kit.ArkUI';
import { taskpool } from '@kit.ArkTS';
import { pasteboard } from '@kit.BasicServicesKit';
import kessh from 'libkessh.so';

@Concurrent
function runPing(host: string, count: number): string {
  return kessh.pingHost(host, count);
}

@Entry
@Component
struct PingTool {
  @State pingHost: string = '';
  @State pingCount: string = '4';
  @State pingResult: string = '';
  @State pingLoading: boolean = false;

  private formatTimestamp(): string {
    const date = new Date();
    const pad = (value: number): string => value.toString().padStart(2, '0');
    return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
  }

  private async copyResult(): Promise<void> {
    if (!this.pingResult) {
      promptAction.showToast({ message: '暂无可复制的结果' });
      return;
    }
    try {
      const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.pingResult);
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      promptAction.showToast({ message: '结果已复制' });
    } catch (err) {
      const error = err as Error;
      promptAction.showToast({ message: `复制失败: ${error.message}` });
    }
  }

  private clearResult(): void {
    this.pingResult = '';
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
    if (count <= 0) count = 4;
    if (count > 10) count = 10;
    
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
        
        Text('Ping 工具')
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
            Text('🌐 网络连通性检测')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Text('快速测试到指定主机的网络延迟和连通性，支持域名和IP地址')
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
            TextInput({ placeholder: '主机或IP地址（例：baidu.com）', text: this.pingHost })
              .onChange((value: string): void => { this.pingHost = value; })
            
            Row({ space: 12 }) {
              TextInput({ placeholder: '次数(1-10)', text: this.pingCount })
                .type(InputType.Number)
                .layoutWeight(1)
                .onChange((value: string): void => { this.pingCount = value; })
              
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
                .onClick((): void => { this.handlePing(); })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(16)

          // 结果显示区域
          if (this.pingResult) {
            Column({ space: 12 }) {
              Row({ space: 8 }) {
                Text('输出结果')
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
              
              Text(this.pingResult)
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
