import { Logger } from '../common/Stores';
import { promptAction, router } from '@kit.ArkUI';
import { LynxBlank, LynxButton, LynxColumn, LynxList, LynxListItem, LynxRow, LynxText } from '../common/LynxUI';

@Entry
@Component
export default struct SettingsLogs {
  @State logs: Array<string> = [];

  aboutToAppear(): void {
    this.refreshLogs();
  }

  private refreshLogs(): void {
    this.logs = Logger.list();
  }

  private clearLogs(): void {
    Logger.clear();
    this.refreshLogs();
    promptAction.showToast({ message: '日志已清空' });
  }

  build() {
    Column() {
      LynxBlank({ style: { height: 36, width: '100%' } })
      LynxRow({ style: { height: 56, width: '100%', padding: { left: 16, right: 16 } } }) {
        LynxButton({
          label: '<',
          style: { height: 36, width: 36, backgroundColor: '#0F000000', borderRadius: 18 },
          onClick: (): void => router.back(),
        })
        LynxText({ content: '日志', style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 12 } } })
        LynxBlank({ style: { layoutWeight: 1 } })
        LynxButton({
          label: '清空',
          style: { height: 36, backgroundColor: '#0F000000', borderRadius: 12 },
          onClick: (): void => { this.clearLogs(); }
        })
      }

      if (this.logs.length > 0) {
        LynxList({ style: { layoutWeight: 1 }, divider: { strokeWidth: 1, color: '#11000000' }, edgeEffect: EdgeEffect.None }) {
          ForEach(this.logs, (item: string, index: number) => {
            LynxListItem({ style: { padding: { left: 16, right: 16, top: 8, bottom: 8 } } }) {
              LynxText({ content: item, style: { fontSize: 12, fontFamily: 'monospace', fontColor: '#DD222222' } })
            }
          }, (item: string, index: number) => `${index}-${item}`)
        }
      } else {
        LynxColumn({ style: { layoutWeight: 1, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center } }) {
          LynxText({ content: '暂无日志', style: { fontSize: 14, fontColor: Color.Grey } })
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
