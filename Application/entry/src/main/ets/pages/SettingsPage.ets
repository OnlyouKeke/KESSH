import { SettingsStore } from '../common/Stores';
import { router } from '@kit.ArkUI';
import hilog from '@ohos.hilog';

@Entry
@Component
export struct SettingsPage {
  build() {
    Column() {
      List() {
        // 子页面入口
        ListItem() {
          Row() {
            Text('密钥管理')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('>')
              .fontColor($r('sys.color.ohos_id_color_fourth'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => { 
          router.pushUrl({ url: 'pages/SettingsKeys' }, (err) => {
            if (err) {
              hilog.error(0xD15A, 'SettingsPage', 'Navigate to SettingsKeys failed: %{public}s', err.message);
            }
          });
        })
        
        ListItem() {
          Row() {
            Text('隐私协议')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('>')
              .fontColor($r('sys.color.ohos_id_color_fourth'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => { 
          router.pushUrl({ url: 'pages/PrivacyPolicy' });
        })
        
        ListItem() {
          Row() {
            Text('用户协议')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('>')
              .fontColor($r('sys.color.ohos_id_color_fourth'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => { 
          router.pushUrl({ url: 'pages/UserAgreement' });
        })
        
        ListItem() {
          Row() {
            Text('问题反馈')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('>')
              .fontColor($r('sys.color.ohos_id_color_fourth'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => { 
          router.pushUrl({ url: 'pages/Feedback' });
        })
        
        ListItem() {
          Row() {
            Text('当前版本')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('1.0.0')
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}