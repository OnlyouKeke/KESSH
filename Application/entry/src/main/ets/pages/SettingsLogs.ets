import { Logger } from '../common/Stores';
import { router } from '@kit.ArkUI';
import { LynxBlank, LynxButton, LynxColumn, LynxRow, LynxScroll, LynxText } from '../common/LynxUI';

@Entry
@Component
export default struct SettingsLogs {
  build() {
    LynxColumn({ style: { width: '100%', height: '100%' } }) {
      // 顶部：状态栏占位 + 标题栏（返回）
      LynxBlank({ style: { height: 36, width: '100%' } })
      LynxRow({ style: { height: 56, width: '100%', padding: { left: 16, right: 16 } } }) {
        LynxButton({
          label: '<',
          style: { height: 36, width: 36, backgroundColor: '#0F000000', borderRadius: 18 },
          onClick: (): void => router.back(),
        })
        LynxText({ content: '日志', style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 12 } } })
        LynxBlank({ style: { layoutWeight: 1 } })
      }

      LynxScroll({ style: { height: 240 }, scrollBar: BarState.Off }) {
        LynxColumn({ style: { padding: { left: 16, right: 16, top: 8, bottom: 8 }, width: '100%' } }) {
          ForEach(Logger.list(), (line: string, idx: number) => {
            LynxText({ content: line, style: { fontSize: 12 } })
          }, (line: string, idx: number) => idx.toString())
        }
      }

      LynxRow({ style: { padding: { left: 16, right: 16, top: 8 } } }) {
        LynxBlank({ style: { layoutWeight: 1 } })
        LynxButton({
          label: '清空日志',
          style: { height: 40, backgroundColor: '#222222', fontColor: Color.White, borderRadius: 12 },
          onClick: (): void => { Logger.clear(); }
        })
        LynxBlank({ style: { layoutWeight: 1 } })
      }
    }
  }
}