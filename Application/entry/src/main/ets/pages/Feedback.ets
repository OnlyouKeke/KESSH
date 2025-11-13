import { router } from '@kit.ArkUI';

@Entry
@Component
export struct Feedback {
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
        
        Text('问题反馈')
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
        Column({ space: 24 }) {
          // 顶部图标
          Text('📧')
            .fontSize(56)
            .margin({ top: 32 })
          
          // 标题
          Text('欢迎反馈问题与建议')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .textAlign(TextAlign.Center)
          
          // 说明文字
          Text('感谢您使用KESSH！您的反馈对我们至关重要，将帮助我们不断改进产品体验。')
            .fontSize(15)
            .lineHeight(24)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ left: 24, right: 24 })
          
          // 反馈类型
          Column({ space: 16 }) {
            Text('您可以反馈以下内容：')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')
            
            Column({ space: 12 }) {
              Row({ space: 12 }) {
                Text('•')
                  .fontSize(18)
                  .fontColor($r('sys.color.ohos_id_color_emphasize'))
                Text('功能异常或BUG')
                  .fontSize(15)
                  .layoutWeight(1)
              }
              .width('100%')
              
              Row({ space: 12 }) {
                Text('•')
                  .fontSize(18)
                  .fontColor($r('sys.color.ohos_id_color_emphasize'))
                Text('新功能建议')
                  .fontSize(15)
                  .layoutWeight(1)
              }
              .width('100%')
              
              Row({ space: 12 }) {
                Text('•')
                  .fontSize(18)
                  .fontColor($r('sys.color.ohos_id_color_emphasize'))
                Text('体验优化建议')
                  .fontSize(15)
                  .layoutWeight(1)
              }
              .width('100%')
              
              Row({ space: 12 }) {
                Text('•')
                  .fontSize(18)
                  .fontColor($r('sys.color.ohos_id_color_emphasize'))
                Text('其他问题与建议')
                  .fontSize(15)
                  .layoutWeight(1)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(12)
          
          // 联系方式
          Column({ space: 16 }) {
            Text('联系方式')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')
            
            // 主要邮箱
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Text('📧')
                  .fontSize(20)
                Text('反馈邮箱')
                  .fontSize(15)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
              .width('100%')
              
              Text('kekeformp1@163.com')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.ohos_id_color_emphasize'))
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .borderRadius(12)
            
            // 备用邮箷
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Text('📧')
                  .fontSize(20)
                Text('备用邮箱')
                  .fontSize(15)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
              .width('100%')
              
              Text('zwjkeke@foxmail.com')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.ohos_id_color_emphasize'))
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .borderRadius(12)
          }
          .width('100%')
          
          // 反馈指南
          Column({ space: 12 }) {
            Text('💡 反馈指南')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')
            
            Text('为了更好地帮助您解决问题，建议您在邮件中包含以下信息：')
              .fontSize(14)
              .lineHeight(22)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%')
            
            Text('1. 问题描述：详细描述遇到的问题\n2. 复现步骤：如何复现该问题\n3. 设备信息：手机型号和系统版本\n4. 应用版本：当前使用的KESSH版本\n5. 截图或日志：如果可能，请附上截图')
              .fontSize(14)
              .lineHeight(22)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(12)
          
          // 底部感谢
          Text('再次感谢您的支持，我们会认真处理每一条反馈！')
            .fontSize(14)
            .lineHeight(22)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 32 })
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
