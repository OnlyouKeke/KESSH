import { Logger, LogLevel, LogEntry } from '../common/Stores';
import { router, promptAction } from '@kit.ArkUI';

@Entry
@Component
struct SettingsLogs {
  @State selectedLevel: string = 'ALL';
  @State autoScroll: boolean = true;
  
  getFilteredLogs(): Array<LogEntry> {
    if (this.selectedLevel === 'ALL') {
      return Logger.list();
    }
    return Logger.list(this.selectedLevel as LogLevel);
  }
  
  getLevelColor(level: LogLevel): Color {
    if (level === 'DEBUG') return Color.Blue;
    if (level === 'INFO') return Color.Green;
    if (level === 'WARN') return Color.Orange;
    if (level === 'ERROR') return Color.Red;
    return Color.Grey;
  }
  
  exportLogs(): void {
    const content = Logger.export();
    // TODO: 实现文件保存功能
    promptAction.showToast({ message: `导出${Logger.list().length}条日志` });
  }
  
  build() {
    Column() {
      // 顶部：状态栏占位 + 标题栏（返回）
      Row() {
        Button({ type: ButtonType.Normal }) {
          Text('<')
            .fontSize(20)
        }
        .height(32)
        .width(32)
        .borderRadius(8)
        .backgroundColor('transparent')
        .onClick((): void => {
          router.back();
        })
        
        Text('日志')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 8 })
        Blank().layoutWeight(1)
        Text(`总计 ${Logger.list().length}`)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .height(56)
      .width('100%')
      .padding({ left: 12, right: 16 })
      
      // 筛选按钮
      Row() {
        Button('全部')
          .type(ButtonType.Normal)
          .height(32)
          .backgroundColor(this.selectedLevel === 'ALL' ? $r('sys.color.ohos_id_color_emphasize') : $r('sys.color.ohos_id_color_button_normal'))
          .fontColor(this.selectedLevel === 'ALL' ? Color.White : $r('sys.color.ohos_id_color_text_primary'))
          .fontSize(14)
          .onClick(() => { this.selectedLevel = 'ALL'; })
        Button('DEBUG')
          .type(ButtonType.Normal)
          .height(32)
          .backgroundColor(this.selectedLevel === 'DEBUG' ? $r('sys.color.ohos_id_color_emphasize') : $r('sys.color.ohos_id_color_button_normal'))
          .fontColor(this.selectedLevel === 'DEBUG' ? Color.White : Color.Blue)
          .fontSize(14)
          .margin({ left: 8 })
          .onClick(() => { this.selectedLevel = 'DEBUG'; })
        Button('INFO')
          .type(ButtonType.Normal)
          .height(32)
          .backgroundColor(this.selectedLevel === 'INFO' ? $r('sys.color.ohos_id_color_emphasize') : $r('sys.color.ohos_id_color_button_normal'))
          .fontColor(this.selectedLevel === 'INFO' ? Color.White : Color.Green)
          .fontSize(14)
          .margin({ left: 8 })
          .onClick(() => { this.selectedLevel = 'INFO'; })
        Button('WARN')
          .type(ButtonType.Normal)
          .height(32)
          .backgroundColor(this.selectedLevel === 'WARN' ? $r('sys.color.ohos_id_color_emphasize') : $r('sys.color.ohos_id_color_button_normal'))
          .fontColor(this.selectedLevel === 'WARN' ? Color.White : Color.Orange)
          .fontSize(14)
          .margin({ left: 8 })
          .onClick(() => { this.selectedLevel = 'WARN'; })
        Button('ERROR')
          .type(ButtonType.Normal)
          .height(32)
          .backgroundColor(this.selectedLevel === 'ERROR' ? $r('sys.color.ohos_id_color_emphasize') : $r('sys.color.ohos_id_color_button_normal'))
          .fontColor(this.selectedLevel === 'ERROR' ? Color.White : Color.Red)
          .fontSize(14)
          .margin({ left: 8 })
          .onClick(() => { this.selectedLevel = 'ERROR'; })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .width('100%')

      Scroll() {
        Column() {
          ForEach(this.getFilteredLogs(), (entry: LogEntry, idx: number) => {
            Row() {
              Text(`[${entry.timeStr}]`)
                .fontSize(10)
                .fontColor(Color.Grey)
                .fontFamily('monospace')
              Text(`[${entry.level}]`)
                .fontSize(10)
                .fontColor(this.getLevelColor(entry.level))
                .fontFamily('monospace')
                .margin({ left: 4 })
              Text(entry.message)
                .fontSize(11)
                .fontFamily('monospace')
                .margin({ left: 4 })
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ top: 2, bottom: 2 })
            .alignItems(VerticalAlign.Top)
          }, (entry: LogEntry, idx: number) => entry.id.toString())
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)

      Row() {
        Button('清空日志')
          .type(ButtonType.Normal)
          .height(40)
          .backgroundColor($r('sys.color.ohos_id_color_warning'))
          .fontColor(Color.White)
          .layoutWeight(1)
          .onClick((): void => { 
            Logger.clear();
            promptAction.showToast({ message: '日志已清空' });
          })
        Button('导出日志')
          .type(ButtonType.Normal)
          .height(40)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .layoutWeight(1)
          .margin({ left: 12 })
          .onClick((): void => { this.exportLogs(); })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }
    .width('100%')
    .height('100%')
  }
}