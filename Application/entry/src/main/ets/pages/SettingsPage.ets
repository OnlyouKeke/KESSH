import { SettingsStore } from '../common/Stores';
import { getLynxPalette } from '../common/LynxTheme';
import { router } from '@kit.ArkUI';
import { LynxBlank, LynxList, LynxListItem, LynxRow, LynxText, LynxToggle } from '../common/LynxUI';

@Entry
@Component
export default struct SettingsPage {
  @StorageLink(SettingsStore.DARK_MODE_KEY) darkMode: boolean = SettingsStore.darkMode;
  @StorageLink(SettingsStore.SAVE_PASSWORD_KEY) savePassword: boolean = SettingsStore.savePassword;
  @State showLogs: boolean = false; // legacy, not used

  private get palette() { return getLynxPalette(this.darkMode); }

  build() {
    Column() {
      LynxList({ style: { width: '100%', layoutWeight: 1, backgroundColor: this.palette.surface } }) {
        // 通用设置
        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } } }) {
          LynxRow() {
            Column({ space: 4 }) {
              LynxText({ content: 'æ·±è‰²æ¨¡å¼', style: { fontSize: 16, fontColor: this.palette.primaryText } })
              LynxText({ content: 'è·Ÿéšç³»ç»Ÿæˆ–æ‰‹åŠ¨åˆ‡æ?', style: { fontSize: 12, fontColor: this.palette.secondaryText } })
            }
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxToggle({ isOn: this.darkMode, onChange: (v: boolean): void => { this.darkMode = v; SettingsStore.setDarkMode(v); } })
          }
        }

        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } } }) {
          LynxRow() {
            Column({ space: 4 }) {
              LynxText({ content: 'ä¿å­˜å¯†ç ', style: { fontSize: 16, fontColor: this.palette.primaryText } })
              LynxText({ content: 'ä½¿ç”¨æœ¬åœ°å®‰å…¨å­˜å‚¨', style: { fontSize: 12, fontColor: this.palette.secondaryText } })
            }
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxToggle({ isOn: this.savePassword, onChange: (v: boolean): void => { this.savePassword = v; SettingsStore.setSavePassword(v); } })
          }
        }

        // 子页面入口
        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } }, onClick: (): void => { router.pushUrl({ url: 'pages/SettingsKeys' }) } }) {
          LynxRow() {
            LynxText({ content: 'å¯†é’¥ç®¡ç†', style: { fontSize: 16 } })
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxText({ content: '>', style: { fontColor: '#66000000' } })
          }
        }

        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } }, onClick: (): void => { router.pushUrl({ url: 'pages/SettingsLogs' }) } }) {
          LynxRow() {
            LynxText({ content: 'æ—¥å¿—', style: { fontSize: 16 } })
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxText({ content: '>', style: { fontColor: '#66000000' } })
          }
        }
      }
      // 已移除保存设置"按键，设置项即时生效
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette.pageBackground)
  }
}
