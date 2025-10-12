import { ConnectionStore, ConnectionRecord, ConnectionDraft } from '../common/Stores';
import { router } from '@kit.ArkUI';

@Entry
@Component
export default struct HistoryPage {
  @State currentIndex: number = 0;
  @State records: Array<ConnectionRecord> = [];

  aboutToAppear(): void {
    const list: Array<ConnectionRecord> = ConnectionStore.list();
    this.records = list;
  }

  // Method to navigate to SSHNewPage with draft data
  private navigateToNewPage(draft: ConnectionDraft): void {
    ConnectionStore.currentDraft = draft;
    router.pushUrl({ url: 'pages/SSHNewPage' });
  }

  @Builder
  renderEmpty() {
    Column({ space: 12 }) {
      Text('暂无历史记录')
        .fontSize(16)
        .fontColor(Color.Grey)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      // 顶部标题与边距（无按钮）
      Row() {
        Text('历史记录')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
        Blank().layoutWeight(1)
      }
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .width('100%')

      if (this.records.length === 0) {
        this.renderEmpty()
      } else {
        List() {
          ForEach(this.records, (item: ConnectionRecord) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                  Text(item.host + ':' + item.port.toString() + ' · ' + item.time)
                    .fontSize(12)
                    .fontColor(Color.Grey)
                }
                Blank().layoutWeight(1)
              }
              .width('100%')
              .height(56)
              .padding({ left: 16, right: 16 })
            }
            .onClick(() => {
              const draft: ConnectionDraft = {
                host: item.host,
                port: item.port.toString(),
                username: item.username
              };
              this.navigateToNewPage(draft);
            })
          }, (item: ConnectionRecord) => item.id.toString())
        }
        .divider({ strokeWidth: 1, color: '#11000000' })
        .edgeEffect(EdgeEffect.None)
      }
    }
    .width('100%')
    .height('100%')
  }
}