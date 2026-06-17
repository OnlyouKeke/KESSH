import { SettingsStore } from '../common/Stores';
import { getLynxPalette, LynxPalette } from '../common/LynxTheme';
import { router } from '@kit.ArkUI';
import { LynxBlank, LynxList, LynxListItem, LynxRow, LynxText, LynxToggle } from '../common/LynxUI';

@Entry
@Component
export default struct SettingsPage {
  @StorageLink(SettingsStore.DARK_MODE_KEY) darkMode: boolean = SettingsStore.darkMode;
  @StorageLink(SettingsStore.SAVE_PASSWORD_KEY) savePassword: boolean = SettingsStore.savePassword;

  private getPalette(): LynxPalette {
    const p = getLynxPalette(this.darkMode);
    if (p) return p;
    return {
      pageBackground: '#F5F7FA',
      surface: '#FFFFFFFF',
      card: '#10E7F0F5',
      primaryText: '#0F1115',
      secondaryText: '#6B7280',
      border: '#11000000',
      accent: '#1E7DD6'
    };
  }

  build() {
    Column() {
      LynxList({ style: { width: '100%', layoutWeight: 1, backgroundColor: this.getPalette().surface } }) {
        // 通用设置
        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } } }) {
          LynxRow() {
            Column({ space: 4 }) {
              LynxText({ content: '深色模式', style: { fontSize: 16, fontColor: this.getPalette().primaryText } })
              LynxText({ content: '跟随系统或手动切换', style: { fontSize: 12, fontColor: this.getPalette().secondaryText } })
            }
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxToggle({ isOn: this.darkMode, onChange: (v: boolean): void => { this.darkMode = v; SettingsStore.setDarkMode(v); } })
          }
        }

        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } } }) {
          LynxRow() {
            Column({ space: 4 }) {
              LynxText({ content: '保存密码', style: { fontSize: 16, fontColor: this.getPalette().primaryText } })
              LynxText({ content: '使用本地安全存储', style: { fontSize: 12, fontColor: this.getPalette().secondaryText } })
            }
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxToggle({ isOn: this.savePassword, onChange: (v: boolean): void => { this.savePassword = v; SettingsStore.setSavePassword(v); } })
          }
        }

        // 子页面入口
        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } }, onTap: (): void => { router.pushUrl({ url: 'pages/SettingsKeys' }) } }) {
          LynxRow() {
            LynxText({ content: '密钥管理', style: { fontSize: 16 } })
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxText({ content: '>', style: { fontColor: '#66000000' } })
          }
        }

        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } }, onTap: (): void => { router.pushUrl({ url: 'pages/SettingsLogs' }) } }) {
          LynxRow() {
            LynxText({ content: '日志', style: { fontSize: 16 } })
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxText({ content: '>', style: { fontColor: '#66000000' } })
          }
        }
      }
      // 已移除“保存设置”按键，设置项即时生效
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageBackground)
  }
}
