import { router } from '@kit.ArkUI';

@Entry
@Component
export struct UserAgreement {
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
        
        Text('用户协议')
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
        Column({ space: 16 }) {
          Text('KESSH 用户服务协议')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          
          Text('欢迎使用KESSH！')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('本协议由张惟钧（以下简称“我们”）与您（以下简称“用户”）共同签订。在使用KESSH应用程序（以下简称“本应用”）之前，请您仔细阅读本协议。您下载、安装和使用本应用，即表示您已经阅读、理解并同意受本协议的约束。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          // 1. 服务内容
          Text('1. 服务内容')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 })
          
          Text('本应用是一款用于SSH远程连接的终端工具，提供以下主要功能：')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('\u2022 SSH远程连接功能\n\u2022 SCP文件传输功能\n\u2022 SSH密钥管理\n\u2022 连接历史记录\n\u2022 多账号数据隔离')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          // 2. 用户权利与义务
          Text('2. 用户权利与义务')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 })
          
          Text('2.1 用户权利')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          
          Text('\u2022 您有权免费使用本应用的所有功能\n\u2022 您的所有数据均存储在本地设备，您拥有完全控制权\n\u2022 您可以随时导出或删除您的数据')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('2.2 用户义务')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          
          Text('\u2022 您应合法使用本应用，不得用于任何非法目的\n\u2022 您应妥善保管SSH密码和私钥\n\u2022 您应对使用本应用连接的远程服务器承担相应责任')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          // 3. 隐私保护
          Text('3. 隐私保护')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 })
          
          Text('我们非常重视您的隐私保护：')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('\u2022 所有数据均存储在您的本地设备，不会上传至任何服务器\n\u2022 SSH密码使用AES-128-GCM算法加密存储\n\u2022 不同华为账号的数据完全隔离\n\u2022 不收集任何个人敏感信息')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('详细隐私政策请查看《隐私政策》。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          // 4. 免责声明
          Text('4. 免责声明')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 })
          
          Text('本应用按“原样”提供，我们不对以下情况承担责任：')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('\u2022 由于网络故障、设备故障等原因导致的服务中断\n\u2022 用户不当使用导致的任何损失\n\u2022 用户未妥善保管密码导致的安全问题\n\u2022 第三方服务器的安全问题')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          // 5. 协议修改
          Text('5. 协议修改')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 })
          
          Text('我们有权在必要时修改本协议。协议修改后，如果您继续使用本应用，即视为您已接受修改后的协议。若您不同意修改后的内容，请停止使用本应用。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          // 6. 联系我们
          Text('6. 联系我们')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 })
          
          Text('如您对本协议有任何疑问，请联系：')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('邮箱：zwjkeke@foxmail.com')
            .fontSize(15)
            .lineHeight(24)
            .fontColor($r('sys.color.ohos_id_color_emphasize'))
            .width('100%')
          
          Text('更新日期：2025.11.13')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .margin({ top: 16 })
          
          Text('生效日期：2025.11.13')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
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
