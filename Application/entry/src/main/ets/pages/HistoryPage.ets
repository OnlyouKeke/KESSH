import { ConnectionStore, ConnectionRecord, ConnectionDraft } from '../common/Stores';
import { router, promptAction } from '@kit.ArkUI';

@Entry
@Component
export struct HistoryPage {
  @State currentIndex: number = 0;
  @State records: Array<ConnectionRecord> = [];
  @State searchText: string = '';
  private timerId: number = -1;

  aboutToAppear(): void {
    this.loadRecords();
    // 每500ms刷新一次列表
    this.timerId = setInterval(() => {
      this.loadRecords();
    }, 500) as number;
  }
  
  aboutToDisappear(): void {
    if (this.timerId > 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }
  
  loadRecords(): void {
    const list: Array<ConnectionRecord> = ConnectionStore.list();
    this.records = list;
  }
  
  getFilteredRecords(): Array<ConnectionRecord> {
    if (!this.searchText) {
      return this.records;
    }
    const searchLower = this.searchText.toLowerCase();
    return this.records.filter(r => 
      r.name.toLowerCase().includes(searchLower) ||
      r.host.toLowerCase().includes(searchLower) ||
      r.username.toLowerCase().includes(searchLower)
    );
  }
  
  getStatusIcon(status?: string): string {
    if (status === 'success') return '✓';
    if (status === 'timeout') return '⏱';
    if (status === 'refused') return '✖';
    if (status === 'auth_failed') return '⚠';
    if (status === 'failed') return '✗';
    return '•';
  }
  
  getStatusColor(status?: string): Color {
    if (status === 'success') return Color.Green;
    if (status === 'timeout') return Color.Orange;
    if (status === 'refused') return Color.Red;
    if (status === 'auth_failed') return Color.Orange;
    if (status === 'failed') return Color.Red;
    return Color.Grey;
  }

  private navigateToNewPage(draft: ConnectionDraft): void {
    ConnectionStore.currentDraft = draft;
    router.pushUrl({ url: 'pages/SSHNewPage' }, (err) => {
      if (err) {
        promptAction.showToast({ message: `导航失败: ${err.message}` });
      }
    });
  }
  
  private showConnectionDialog(item: ConnectionRecord): void {
    promptAction.showActionMenu({
      title: '选择操作',
      buttons: [
        { text: 'SSH连接', color: '#007AFF' },
        { text: 'SCP传输', color: '#007AFF' }
      ]
    }).then((result) => {
      if (result.index === 0) {
        // SSH连接 - 跳转到添加主机页面，自动填充信息
        const savedPassword = ConnectionStore.getPassword(item);
        const draft: ConnectionDraft = {
          host: item.host,
          port: item.port.toString(),
          username: item.username,
          password: savedPassword // 如果有保存的密码，自动填充
        };
        this.navigateToNewPage(draft);
      } else if (result.index === 1) {
        // SCP
        promptAction.showToast({ message: 'SCP功能待实现' });
      }
    }).catch((err: Error) => {
      // 用户取消
    });
  }
  
  private deleteRecord(id: number): void {
    ConnectionStore.remove(id);
    this.loadRecords();
    promptAction.showToast({ message: '已删除' });
  }
  
  private clearAllRecords(): void {
    ConnectionStore.clearAll();
    this.loadRecords();
    promptAction.showToast({ message: '已清空主机列表' });
  }
  
  @Builder
  buildDeleteButton(id: number) {
    Button('删除')
      .width(60)
      .height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_warning'))
      .fontColor(Color.White)
      .onClick(() => { this.deleteRecord(id); })
  }

  @Builder
  renderEmpty() {
    Column({ space: 12 }) {
      Text('暂无主机')
        .fontSize(16)
        .fontColor(Color.Grey)
      Text('点击底部“添加主机”按钮添加')
        .fontSize(14)
        .fontColor(Color.Grey)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Text('主机')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
        Blank().layoutWeight(1)
        if (this.records.length > 0) {
          Button('清空')
            .type(ButtonType.Normal)
            .height(32)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .onClick(() => { this.clearAllRecords(); })
        }
      }
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .width('100%')
      
      if (this.records.length > 0) {
        TextInput({ placeholder: '搜索主机或用户名', text: this.searchText })
          .onChange((v: string): void => { this.searchText = v; })
          .margin({ left: 16, right: 16, bottom: 8 })
      }

      if (this.records.length === 0) {
        this.renderEmpty()
      } else {
        List({ space: 12 }) {
          ForEach(this.getFilteredRecords(), (item: ConnectionRecord) => {
          ListItem() {
            Row() {
              // 主机信息
              Column({ space: 6 }) {
                Text(item.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                
                Row({ space: 8 }) {
                  Text(`${item.host}:${item.port.toString()}`)
                    .fontSize(14)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  Text(`· ${item.username}`)
                    .fontSize(14)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              
              // 右侧箭头
              Text('>')
                .fontSize(20)
                .fontColor($r('sys.color.ohos_id_color_fourth'))
            }
            .width('100%')
            .padding(12)
          }
          .onClick(() => {
            this.showConnectionDialog(item);
          })
          .swipeAction({ end: this.buildDeleteButton(item.id) })
        }, (item: ConnectionRecord) => item.id.toString())
      }
      .divider({ strokeWidth: 1, color: $r('sys.color.ohos_id_color_list_separator'), startMargin: 12, endMargin: 12 })
      .edgeEffect(EdgeEffect.Spring)
    }
  }
  .width('100%')
  .height('100%')
  }
}
