import { promptAction } from '@kit.ArkUI';

interface ConnectionOption {
  key: string;
  title: string;
  description: string;
  icon: string;
  elevated?: boolean;
}

const OPTIONS: Array<ConnectionOption> = [
  {
    key: 'local',
    title: 'Local',
    description: 'Start a local session without remote hosts',
    icon: '\ud83d\udcbb',
    elevated: true,
  },
  {
    key: 'add',
    title: 'Add host',
    description: 'Connect with SSH to a remote machine',
    icon: '\ud83d\udd11',
  },
  {
    key: 'sftp',
    title: 'Connect via SFTP',
    description: 'Transfer files securely over SSH',
    icon: '\ud83d\udce6',
  },
  {
    key: 'discover',
    title: 'Discover local devices',
    description: 'Find hosts on your local network',
    icon: '\ud83e\uddfe',
  },
  {
    key: 'serial',
    title: 'Start a serial connection',
    description: 'Plug in and open a serial console',
    icon: '\ud83d\udcf1',
  },
];

@Entry
@Component
export default struct SSHNewPage {
  private onSelect(option: ConnectionOption): void {
    promptAction.showToast({ message: `${option.title} 即将打开` });
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          TextInput({ placeholder: "Search or 'ssh user@hostname -p port'" })
            .height(44)
            .padding({ left: 16, right: 16 })
            .backgroundColor('#10E7F0F5')
            .borderRadius(14)

          Column({ space: 6 }) {
            Text('Ways to connect')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
            Text('Connect via SSH, discover devices on your local network, or use a serial cable.')
              .fontSize(13)
              .fontColor(Color.Grey)
          }

          Column({ space: 12 }) {
            ForEach(OPTIONS, (item: ConnectionOption) => {
              Column() {
                Row() {
                  Text(item.icon)
                    .fontSize(20)
                    .margin({ right: 12 })

                  Column({ space: 4 }) {
                    Text(item.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                    Text(item.description)
                      .fontSize(13)
                      .fontColor(Color.Grey)
                  }

                  Blank().layoutWeight(1)

                  Text('›')
                    .fontSize(18)
                    .fontColor('#7A7A7A')
                }
              }
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor(item.elevated ? '#14B0DBFF' : '#10E7F0F5')
              .borderRadius(18)
              .onClick((): void => { this.onSelect(item); })
            }, (item: ConnectionOption) => item.key)
          }
        }
        .padding({ left: 16, right: 16, bottom: 24 })
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
  }
}
