import { promptAction } from '@kit.ArkUI';

interface ConnectionOption {
  key: string;
  title: string;
  description: string;
  icon: string;
  badge?: string;
}

const OPTIONS: Array<ConnectionOption> = [
  {
    key: 'local',
    title: '本地终端',
    description: '直接在本机启动终端，无需远程连接',
    icon: '\uD83C\uDF10',
    badge: '新增',
  },
  {
    key: 'add',
    title: '添加主机',
    description: '通过 SSH 登录或管理新的远程主机',
    icon: '\uD83D\uDCE6',
  },
  {
    key: 'scp',
    title: 'SCP 传输',
    description: '使用 SCP 在设备之间安全传输文件',
    icon: '\uD83D\uDCE4',
  },
];

@Entry
@Component
export default struct SSHNewPage {
  private onSelect(option: ConnectionOption): void {
    const toast = option.key === 'local'
      ? `${option.title} 功能即将打开`
      : `${option.title} 功能保持不变`;
    promptAction.showToast({ message: toast });
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          Text('连接方式')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 8 })

          TextInput({ placeholder: '搜索或输入 ssh user@主机 -p 端口' })
            .height(42)
            .padding({ left: 14, right: 14 })
            .backgroundColor('#0F000000')
            .borderRadius(12)

          ForEach(OPTIONS, (item: ConnectionOption) => {
            Column() {
              Row() {
                Text(item.icon)
                  .fontSize(22)
                Column({ space: 4 }) {
                  Row() {
                    Text(item.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                    if (item.badge) {
                      Text(item.badge)
                        .fontSize(11)
                        .fontColor('#FF6B00')
                        .backgroundColor('#14FF6B00')
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .borderRadius(10)
                        .margin({ left: 8 })
                    }
                  }
                  Text(item.description)
                    .fontSize(13)
                    .fontColor(Color.Grey)
                }
                .margin({ left: 12 })
                Blank().layoutWeight(1)
                Text('›')
                  .fontSize(18)
                  .fontColor(Color.Grey)
              }
            }
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .backgroundColor('#0A000000')
            .borderRadius(16)
            .onClick((): void => { this.onSelect(item); })
          }, (item: ConnectionOption) => item.key)
        }
        .padding(16)
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
