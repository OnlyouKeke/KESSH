import HistoryPage from './HistoryPage';
import SSHNewPage from './SSHNewPage';
import SettingsPage from './SettingsPage';
import TitleBar from '../components/TitleBar';
import { SSHEngine } from '../common/NativeSSH';
import { LynxBlank, LynxColumn, LynxTabs } from '../common/LynxUI';

let startupProbeDone: boolean = false;

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  aboutToAppear(): void {
    if (!startupProbeDone) {
      startupProbeDone = true;
      SSHEngine.startupDiagnostic();
    }
  }

  build() {
    LynxColumn({ style: { height: '100%', width: '100%' } }) {
      // 信号栏占位（36vp）
      LynxBlank({ style: { height: 36, width: '100%' } })

      // 一级界面标题栏（56vp）：首页不显示标题，移除右侧两个按钮
      TitleBar({ title: this.currentIndex === 0 ? 'Personal' : (this.currentIndex === 1 ? 'Connections' : 'Settings'), showActions: false })

      // 内容区：底部 Tab
      LynxTabs({
        index: this.currentIndex,
        barPosition: BarPosition.End,
        barMode: BarMode.Fixed,
        style: { layoutWeight: 1, width: '100%' },
        onChange: (idx: number) => { this.currentIndex = idx; },
        items: [
          { title: 'Vaults', builder: () => HistoryPage({ currentIndex: this.currentIndex }) },
          { title: 'Connections', builder: () => SSHNewPage() },
          { title: 'Settings', builder: () => SettingsPage() },
        ]
      })
    }
  }
}
