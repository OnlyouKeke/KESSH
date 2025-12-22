import { Logger } from '../common/Stores';
import { router } from '@kit.ArkUI';
import { LynxBlank, LynxButton, LynxRow, LynxScroll, LynxText } from '../common/LynxUI';

@Entry
@Component
export default struct SettingsLogs {
  build() {
    Column() {
      // 顶部：状态栏占位 + 标题栏（返回）
      LynxBlank({ style: { height: 36, width: '100%' } })
      LynxRow({ style: { height: 56, width: '100%', padding: { left: 16, right: 16 } } }) {
        LynxButton({
          label: '<',
          style: { height: 36, width: 36, backgroundColor: '#0F000000', borderRadius: 18 },
          onClick: (): void => router.back(),
        })
        LynxText({ content: 'æ—¥å¿—', style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 12 } } })
        LynxBlank({ style: { layoutWeight: 1 } })
      }

      LynxScroll({ style: { height: 240 }, scrollBar: BarState.Off }) {
        Column() {
          ForEach(Logger.list(), (line: string, idx: number) => {
            LynxText({ content: line, style: { fontSize: 12 } })
          }, (line: string, idx: number) => idx.toString())
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .width('100%')
      }

      LynxRow({ style: { padding: { left: 16, right: 16, top: 8 } } }) {
        LynxBlank({ style: { layoutWeight: 1 } })
        LynxButton({
          label: 'æ¸…ç©ºæ—¥å¿—',
          style: { height: 40, backgroundColor: '#222222', fontColor: Color.White, borderRadius: 12 },
          onClick: (): void => { Logger.clear(); }
        })
        LynxBlank({ style: { layoutWeight: 1 } })
      }
    }
    .width('100%')
    .height('100%')
  }
}
