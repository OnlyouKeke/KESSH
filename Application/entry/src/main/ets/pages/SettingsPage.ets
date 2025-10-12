import { SettingsStore } from '../common/Stores';
import { router } from '@kit.ArkUI';

@Entry
@Component
export default struct SettingsPage {
  @State darkMode: boolean = SettingsStore.darkMode;
  @State savePassword: boolean = SettingsStore.savePassword;
  @State showLogs: boolean = false; // legacy, not used

  build() {
    Column() {
      List() {
        // 通用设置
        ListItem() {
          Row() {
            Column() {
              Text('深色模式')
                .fontSize(16)
              Text('跟随系统或手动切换')
                .fontSize(12)
                .fontColor(Color.Grey)
            }
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Center)
            .width('70%')
            Blank().layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.darkMode })
              .onChange((v: boolean): void => { this.darkMode = v; SettingsStore.setDarkMode(v); })
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }

        ListItem() {
          Row() {
            Column() {
              Text('保存密码')
                .fontSize(16)
              Text('使用本地安全存储')
                .fontSize(12)
                .fontColor(Color.Grey)
            }
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Center)
            .width('70%')
            Blank().layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.savePassword })
              .onChange((v: boolean): void => { this.savePassword = v; SettingsStore.setSavePassword(v); })
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }

        // 子页面入口
        ListItem() {
          Row() {
            Text('密钥管理')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('>')
              .fontColor('#66000000')
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => { router.pushUrl({ url: 'pages/SettingsKeys' }) })

        ListItem() {
          Row() {
            Text('日志')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('>')
              .fontColor('#66000000')
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => { router.pushUrl({ url: 'pages/SettingsLogs' }) })
      }
      .width('100%')
      .layoutWeight(1)
      // 已移除"保存设置"按钮，设置项即时生效
    }
    .width('100%')
    .height('100%')
  }
}