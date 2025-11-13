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
        Column({ space: 16 }) {
          Text('KESSH 隐私政策')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          
          Text('KESSH 是由张惟钧（以下简称“我们”）为您提供的，用于终竫SSH连接的应用。本隐私声明由我们为处理您的个人信息而制定。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('我们非常重视您的个人信息和隐私保护，将会按照法律要求和业界成熟的安全标准，为您的个人信息提供相应的安全保护措施。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          // 1. 信息收集和使用
          Text('1. 我们如何收集和使用您的个人信息')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 })
          
          Text('我们仅在有合法性基础的情形下才会使用您的个人信息。根据适用的法律，我们可能会基于您的同意、为履行/订立您与我们的合同所必需、履行法定义务所必需等合法性基础，使用您的个人信息。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('1.1 密钥跨设备管理功能')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          
          Text('我们为您提供密钥跨设备管理功能，在您使用相关业务的过程中，我们会处理所必需的信息，以便履行我们的合同义务。若您不提供相关信息，会影响到您使用本应用的相关功能/服务。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('为了实现应用功能，在获取您的同意后，我们需要收集您的用户标识符。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          // 2. 设备权限
          Text('2. 设备权限调用')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 })
          
          Text('图片和视频（允许应用保存图片、视频到用户公共目录）')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          
          Text('在使用SCP功能时，需要访问该权限以便上传和下载文件。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          // 3. 数据管理
          Text('3. 管理您的个人信息')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 })
          
          Text('如您对您的数据主体权利有进一步要求或存在任何疑问、意见或建议，可通过本声明中“如何联系我们”章节中所述方式与我们取得联系，并行使您的相关权利。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          // 4. 信息存储
          Text('4. 信息存储地点及期限')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 })
          
          Text('4.1 我们承诺，除法律法规另有规定外，我们对您的信息的保存期限应当为实现处理目的所必要的最短时间。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('4.2 所有数据均存储于您的本地设备，不会上传至任何服务器。SSH密码使用AES-128-GCM算法加密存储于应用沙箱中，确保数据安全。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          // 5. 联系方式
          Text('5. 如何联系我们')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 8 })
          
          Text('您可通过以下方式联系我们，并行使您的相关权利，我们会尽快回复。')
            .fontSize(15)
            .lineHeight(24)
            .width('100%')
          
          Text('邮箱：zwjkeke@foxmail.com')
            .fontSize(15)
            .lineHeight(24)
            .fontColor($r('sys.color.ohos_id_color_emphasize'))
            .width('100%')
          
          Text('如果您对我们的回复不满意，特别是当个人信息处理行为损害了您的合法权益时，您还可以通过向有管辖权的人民法院提起诉讼、向行业自律协会或政府相关管理机构投诉等外部途径进行解决。')
            .fontSize(15)
            .lineHeight(24)
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
