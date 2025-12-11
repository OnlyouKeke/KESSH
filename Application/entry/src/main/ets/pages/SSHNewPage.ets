import { promptAction } from '@kit.ArkUI';
import { LynxBlank, LynxColumn, LynxRow, LynxScroll, LynxText, LynxTextInput } from '../common/LynxUI';

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
    LynxColumn({ style: { width: '100%', height: '100%', backgroundColor: '#F5F7FA' } }) {
      LynxScroll({ style: { width: '100%', height: '100%' }, scrollBar: BarState.Off }) {
        LynxColumn({ space: 16, style: { padding: { left: 16, right: 16, bottom: 24 }, width: '100%' } }) {
          LynxTextInput({
            placeholder: "Search or 'ssh user@hostname -p port'",
            style: { height: 44, padding: { left: 16, right: 16 }, backgroundColor: '#10E7F0F5', borderRadius: 14 }
          })

          LynxColumn({ space: 6 }) {
            LynxText({ content: 'Ways to connect', style: { fontSize: 18, fontWeight: FontWeight.Medium } })
            LynxText({ content: 'Connect via SSH, discover devices on your local network, or use a serial cable.', style: { fontSize: 13, fontColor: Color.Grey } })
          }

          LynxColumn({ space: 12 }) {
            ForEach(OPTIONS, (item: ConnectionOption) => {
              LynxColumn({
                style: {
                  padding: { left: 16, right: 16, top: 14, bottom: 14 },
                  backgroundColor: item.elevated ? '#14B0DBFF' : '#10E7F0F5',
                  borderRadius: 18
                },
                onClick: (): void => { this.onSelect(item); }
              }) {
                LynxRow() {
                  LynxText({ content: item.icon, style: { fontSize: 20, margin: { right: 12 } } })

                  LynxColumn({ space: 4 }) {
                    LynxText({ content: item.title, style: { fontSize: 16, fontWeight: FontWeight.Medium } })
                    LynxText({ content: item.description, style: { fontSize: 13, fontColor: Color.Grey } })
                  }

                  LynxBlank({ style: { layoutWeight: 1 } })

                  LynxText({ content: '›', style: { fontSize: 18, fontColor: '#7A7A7A' } })
                }
              }
            }, (item: ConnectionOption) => item.key)
          }
        }
      }
    }
  }
}
