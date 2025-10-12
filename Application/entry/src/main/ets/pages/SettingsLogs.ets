import { Logger } from '../common/Stores';
import { router } from '@kit.ArkUI';

@Entry
@Component
export default struct SettingsLogs {
  build() {
    Column() {
      // 顶部：状态栏占位 + 标题栏（返回）
      Blank().height(36).width('100%')
      Row() {
        Button('<')
          .type(ButtonType.Normal)
          .height(36)
          .width(36)
          .backgroundColor('#0F000000')
          .borderRadius(18)
          .onClick((): void => router.back())
        Text('日志')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
        Blank().layoutWeight(1)
      }
      .height(56)
      .width('100%')
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column() {
          ForEach(Logger.list(), (line: string, idx: number) => {
            Text(line).fontSize(12)
          }, (line: string, idx: number) => idx.toString())
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .width('100%')
      }
      .height(240)
      .scrollBar(BarState.Off)

      Row() {
        Blank().layoutWeight(1)
        Button('清空日志')
          .type(ButtonType.Normal)
          .height(40)
          .backgroundColor('#222222')
          .fontColor(Color.White)
          .borderRadius(12)
          .onClick((): void => { Logger.clear(); })
        Blank().layoutWeight(1)
      }
      .padding({ left: 16, right: 16, top: 8 })
    }
    .width('100%')
    .height('100%')
  }
}