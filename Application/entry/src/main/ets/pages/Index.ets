import { HistoryPage } from './HistoryPage';
import { SSHNewPage } from './SSHNewPage';
import { SettingsPage } from './SettingsPage';
import TitleBar from '../components/TitleBar';
import { SSHEngine } from '../common/SSHEngine';

let startupProbeDone: boolean = false;

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  aboutToAppear(): void {
    if (!startupProbeDone) {
      startupProbeDone = true;
      // SSHEngine.startupDiagnostic();
    }
  }

  build() {
    Column() {
      // 信号栏占位（36vp）
      Blank().height(36).width('100%')

      // 一级界面标题栏（56vp）：首页不显示标题，移除右侧两个按钮
      TitleBar({ title: this.currentIndex === 0 ? '' : (this.currentIndex === 1 ? '添加主机' : '设置'), showActions: false })

      // 内容区：底部 Tab
      Tabs({ index: this.currentIndex }) {
        TabContent() {
          HistoryPage({ currentIndex: this.currentIndex })
        }
        .tabBar({ text: '首页' })

        TabContent() {
          SSHNewPage()
        }
        .tabBar({ 
          icon: $r('sys.symbol.plus_circle'),
          text: '添加主机'
        })

        TabContent() {
          SettingsPage()
        }
        .tabBar({ text: '设置' })
      }
      .barPosition(BarPosition.End)
      .barMode(BarMode.Fixed)
      .layoutWeight(1)
      .width('100%')
    }
    .height('100%')
    .width('100%')
  }
}
