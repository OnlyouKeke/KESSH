import { SettingsStore } from '../common/Stores';
import { router } from '@kit.ArkUI';
import { LynxBlank, LynxColumn, LynxList, LynxListItem, LynxRow, LynxText, LynxToggle } from '../common/LynxUI';

@Entry
@Component
export default struct SettingsPage {
  @State darkMode: boolean = SettingsStore.darkMode;
  @State savePassword: boolean = SettingsStore.savePassword;
  @State showLogs: boolean = false; // legacy, not used

  build() {
    LynxColumn({ style: { width: '100%', height: '100%' } }) {
      LynxList({ style: { width: '100%', layoutWeight: 1 } }) {
        // 通用设置
        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } } }) {
          LynxRow() {
            LynxColumn({ style: { alignItems: HorizontalAlign.Start, justifyContent: FlexAlign.Center, width: '70%' } }) {
              LynxText({ content: '深色模式', style: { fontSize: 16 } })
              LynxText({ content: '跟随系统或手动切换', style: { fontSize: 12, fontColor: Color.Grey } })
            }
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxToggle({ isOn: this.darkMode, onChange: (v: boolean): void => { this.darkMode = v; SettingsStore.setDarkMode(v); } })
          }
        }

        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } } }) {
          LynxRow() {
            LynxColumn({ style: { alignItems: HorizontalAlign.Start, justifyContent: FlexAlign.Center, width: '70%' } }) {
              LynxText({ content: '保存密码', style: { fontSize: 16 } })
              LynxText({ content: '使用本地安全存储', style: { fontSize: 12, fontColor: Color.Grey } })
            }
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxToggle({ isOn: this.savePassword, onChange: (v: boolean): void => { this.savePassword = v; SettingsStore.setSavePassword(v); } })
          }
        }

        // 子页面入口
        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } }, onClick: (): void => { router.pushUrl({ url: 'pages/SettingsKeys' }) } }) {
          LynxRow() {
            LynxText({ content: '密钥管理', style: { fontSize: 16 } })
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxText({ content: '>', style: { fontColor: '#66000000' } })
          }
        }

        LynxListItem({ style: { width: '100%', height: 56, padding: { left: 16, right: 16 } }, onClick: (): void => { router.pushUrl({ url: 'pages/SettingsLogs' }) } }) {
          LynxRow() {
            LynxText({ content: '日志', style: { fontSize: 16 } })
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxText({ content: '>', style: { fontColor: '#66000000' } })
          }
        }
      }
      // 已移除"保存设置"按钮，设置项即时生效
    }
  }
}