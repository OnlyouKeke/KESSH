import { promptAction } from '@kit.ArkUI';
import { LynxBlank, LynxColumn, LynxRow, LynxScroll, LynxText, LynxTextInput } from '../common/LynxUI';
import { getLynxPalette, LynxPalette } from '../common/LynxTheme';
import { SettingsStore } from '../common/Stores';

interface ConnectionOption {
  key: string;
  title: string;
  description: string;
  icon: string;
  elevated?: boolean;
}

const OPTIONS: Array<ConnectionOption> = [
  { key: 'local', title: 'Local', description: 'Start a local session without remote hosts', icon: '💻', elevated: true },
  { key: 'add', title: 'Add host', description: 'Connect with SSH to a remote machine', icon: '🔑' },
  { key: 'sftp', title: 'Connect via SFTP', description: 'Transfer files securely over SSH', icon: '📦' },
  { key: 'discover', title: 'Discover devices', description: 'Find hosts on your local network', icon: '🧾' },
  { key: 'serial', title: 'Serial', description: 'Plug in and open a serial console', icon: '📱' },
];

@Entry
@Component
export default struct SSHNewPage {
  @StorageLink(SettingsStore.DARK_MODE_KEY) darkMode: boolean = SettingsStore.darkMode;

  private get palette(): LynxPalette { return getLynxPalette(this.darkMode); }

  private onSelect(option: ConnectionOption): void {
    promptAction.showToast({ message: `${option.title} will open soon` });
  }

  build() {
    LynxColumn({ style: { width: '100%', height: '100%', backgroundColor: this.palette.pageBackground } }) {
      LynxScroll({ style: { width: '100%', height: '100%' }, scrollBar: BarState.Off }) {
        LynxColumn({ space: 16 }) {
          LynxTextInput({
            placeholder: "Search or 'ssh user@hostname -p port'",
            style: { height: 44, padding: { left: 16, right: 16 }, backgroundColor: this.palette.card, borderRadius: 14 }
          })

          LynxColumn({ space: 6 }) {
            LynxText({ content: 'Ways to connect', style: { fontSize: 18, fontWeight: FontWeight.Medium, fontColor: this.palette.primaryText } })
            LynxText({ content: 'Connect via SSH, discover devices, or use serial.', style: { fontSize: 13, fontColor: this.palette.secondaryText } })
          }

          LynxColumn({ space: 12 }) {
            ForEach(OPTIONS, (item: ConnectionOption) => {
              LynxColumn({
                space: 8,
                style: {
                  padding: { left: 16, right: 16, top: 14, bottom: 14 },
                  backgroundColor: item.elevated ? this.palette.accent : this.palette.surface,
                  borderRadius: 18
                },
                onClick: (): void => { this.onSelect(item); }
              }) {
                LynxRow() {
                  LynxText({ content: item.icon, style: { fontSize: 20, margin: { right: 12 }, fontColor: this.palette.primaryText } })

                  LynxColumn({ space: 4 }) {
                    LynxText({ content: item.title, style: { fontSize: 16, fontWeight: FontWeight.Medium, fontColor: this.palette.primaryText } })
                    LynxText({ content: item.description, style: { fontSize: 13, fontColor: this.palette.secondaryText } })
                  }

                  LynxBlank({ style: { layoutWeight: 1 } })

                  LynxText({ content: '>', style: { fontSize: 18, fontColor: this.palette.secondaryText } })
                }
              }
            }, (item: ConnectionOption) => item.key)
          }
        }
        .padding({ left: 16, right: 16, bottom: 24 })
      }
    }
  }
}
