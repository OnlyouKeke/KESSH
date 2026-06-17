import HistoryPage from './HistoryPage';
import SSHNewPage from './SSHNewPage';
import SettingsPage from './SettingsPage';
import TitleBar from '../components/TitleBar';
import { SSHEngine } from '../common/SSHEngine';
import { LynxBlank } from '../common/LynxUI';
import { SettingsStore } from '../common/Stores';
import { getLynxPalette, LynxPalette } from '../common/LynxTheme';

let startupProbeDone: boolean = false;

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @StorageLink(SettingsStore.DARK_MODE_KEY) darkMode: boolean = SettingsStore.darkMode;

  aboutToAppear(): void {
    SettingsStore.ensureInitialized();
    if (!startupProbeDone) {
      startupProbeDone = true;
      SSHEngine.startupDiagnostic();
    }
  }

  private getPalette(): LynxPalette {
    let p: LynxPalette | undefined;
    try {
      p = getLynxPalette(this.darkMode);
    } catch (e) {
      // ignore
    }

    if (p) {
      return p;
    }
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
      // 状态栏占位
      LynxBlank({ style: { height: 36, width: '100%' } })

      // 顶部标题栏
      TitleBar({ title: this.currentIndex === 0 ? '个人' : (this.currentIndex === 1 ? '连接' : '设置'), showActions: false })

      // Tab 内容
      Tabs({ index: this.currentIndex }) {
        TabContent() { HistoryPage(); }
          .tabBar({ text: '资产' });
        TabContent() { SSHNewPage(); }
          .tabBar({ text: '连接' });
        TabContent() { SettingsPage(); }
          .tabBar({ text: '设置' });
      }
      .barPosition(BarPosition.End)
      .barMode(BarMode.Fixed)
      .onChange((idx: number): void => { this.currentIndex = idx; })
      .layoutWeight(1)
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageBackground);
  }
}
