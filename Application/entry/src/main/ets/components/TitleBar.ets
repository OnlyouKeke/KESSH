import { LynxBlank, LynxButton, LynxRow, LynxText } from '../common/LynxUI';

@Component
export default struct TitleBar {
  @Prop title: string = '';
  @Prop showActions: boolean = false;

  build() {
    LynxRow({ style: { height: 56, width: '100%' } }) {
      // 左侧标题；若为空，用 16vp 占位保持对齐
      if (this.title && this.title.length > 0) {
        LynxText({
          content: this.title,
          style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 16 } }
        })
      } else {
        LynxBlank({ style: { width: 16 } })
      }

      LynxBlank({ style: { layoutWeight: 1 } })

      // 右侧操作区：默认不显示；需要时作为 36vp 胶囊按钮组
      if (this.showActions) {
        LynxRow({
          style: {
            padding: { left: 12, right: 12 },
            margin: { right: 16 },
            backgroundColor: '#0F000000',
            borderRadius: 18,
            height: 36
          }
        }) {
          LynxButton({ label: '···', style: { height: 36, width: 36, textSize: 18 } })
          LynxBlank({ style: { width: 8 } })
          LynxButton({ label: '—', style: { height: 36, width: 36, textSize: 18 } })
        }
      } else {
        // 右侧占位，保持边距
        LynxBlank({ style: { width: 16 } })
      }
    }
  }
}