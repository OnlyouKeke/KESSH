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

  private get palette(): LynxPalette { return getLynxPalette(this.darkMode); }

  aboutToAppear(): void {
    if (!startupProbeDone) {
      startupProbeDone = true;
      SSHEngine.startupDiagnostic();
    }
  }

  build() {
    Column() {
      // 状态栏占位
      LynxBlank({ style: { height: 36, width: '100%' } })

      // 顶部标题栏
      TitleBar({ title: this.currentIndex === 0 ? 'Personal' : (this.currentIndex === 1 ? 'Connections' : 'Settings'), showActions: false })

      // Tab 内容
      Tabs({ index: this.currentIndex }) {
        TabContent() { HistoryPage(); }
          .tabBar({ text: 'Vaults' });
        TabContent() { SSHNewPage(); }
          .tabBar({ text: 'Connections' });
        TabContent() { SettingsPage(); }
          .tabBar({ text: 'Settings' });
      }
      .barPosition(BarPosition.End)
      .barMode(BarMode.Fixed)
      .onChange((idx: number): void => { this.currentIndex = idx; })
      .layoutWeight(1)
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette.pageBackground);
  }
}
