import HistoryPage from './HistoryPage';
import SSHNewPage from './SSHNewPage';
import SettingsPage from './SettingsPage';
import TitleBar from '../components/TitleBar';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  build() {
    Column() {
      // 信号栏占位（36vp）
      Blank().height(36).width('100%')

      // 一级界面标题栏（56vp）：首页不显示标题，移除右侧两个按钮
      TitleBar({ title: this.currentIndex === 0 ? '' : (this.currentIndex === 1 ? '连接' : '设置'), showActions: false })

      // 内容区：底部 Tab
      Tabs({ index: this.currentIndex }) {
        TabContent() {
          HistoryPage({ currentIndex: $currentIndex })
        }
        .tabBar({ text: '首页' })

        TabContent() {
          SSHNewPage()
        }
        .tabBar({ text: '连接' })

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