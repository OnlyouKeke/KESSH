import { router } from '@kit.ArkUI';

@Entry
@Component
export struct PrivacyPolicy {
  build() {
    Column() {
      // 顶部标题栏(返回)
      Row() {
        Text('<')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick((): void => {
            router.back();
          })
        
        Text('隐私协议')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 4 })
        Blank().layoutWeight(1)
      }
      .height(56)
      .width('100%')
      .padding({ left: 8, right: 16 })
      
      // 内容区
      Scroll() {
        Column() {
          Text('隐私协议内容待完善')
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 100 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
