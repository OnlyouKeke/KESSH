import { LynxBlank, LynxColumn, LynxRow, LynxScroll, LynxText } from '../common/LynxUI';

interface VaultItem {
  key: string;
  title: string;
  subtitle: string;
  icon: string;
  badge?: string;
}

@Entry
@Component
export default struct HistoryPage {
  private quickActions: Array<string> = ['\ud83d\udcc2', '\ud83d\udee1', '\ud83d\udd14'];

  private vaultItems: Array<VaultItem> = [
    { key: 'hosts', title: 'Hosts', subtitle: 'Manage SSH hosts and saved sessions', icon: '\ud83d\udcbb' },
    { key: 'keychain', title: 'Keychain', subtitle: 'Local keychain & identity', icon: '\ud83d\udd10' },
    { key: 'port', title: 'Port forwarding', subtitle: 'Tunnels & jump hosts', icon: '\ud83d\udce6' },
    { key: 'snippets', title: 'Snippets', subtitle: 'Reuse common commands', icon: '\ud83e\uddce' },
    { key: 'known', title: 'Known hosts', subtitle: 'Fingerprints you trust', icon: '\ud83e\udded' },
    { key: 'logs', title: 'Logs', subtitle: 'Recent activity and audit trail', icon: '\ud83d\uddc3', badge: '1' },
  ];

  @Builder
  buildQuickActions() {
    LynxRow({ space: 12, style: { width: '100%', justifyContent: FlexAlign.SpaceBetween } }) {
      ForEach(this.quickActions, (icon: string, index: number) => {
        LynxColumn({
            style: {
              width: 64,
              height: 64,
              borderRadius: 18,
              backgroundColor: '#1AE7F0F5',
              justifyContent: FlexAlign.Center,
              alignItems: ItemAlign.Center
            }
          }) {
            LynxText({ content: icon, style: { fontSize: 20 } })
          }
      }, (icon: string, index: number) => index.toString())
    }
  }

  @Builder
  buildVaultItem(item: VaultItem) {
    LynxRow({ style: { padding: { left: 16, right: 16, top: 14, bottom: 14 }, backgroundColor: '#10E7F0F5', borderRadius: 18 } }) {
      LynxText({ content: item.icon, style: { fontSize: 20, margin: { right: 12 } } })

      LynxColumn({ space: 4 }) {
        LynxText({ content: item.title, style: { fontSize: 16, fontWeight: FontWeight.Medium } })
        LynxText({ content: item.subtitle, style: { fontSize: 13, fontColor: Color.Grey } })
      }

      LynxBlank({ style: { layoutWeight: 1 } })

      LynxRow({ space: 8 }) {
        if (item.badge) {
          LynxText({
            content: item.badge,
            style: {
              fontSize: 12,
              fontColor: '#ffffff',
              backgroundColor: '#1E7DD6',
              padding: { left: 8, right: 8, top: 4, bottom: 4 },
              borderRadius: 12
            }
          })
        }
        LynxText({ content: '›', style: { fontSize: 18, fontColor: '#7A7A7A' } })
      }
    }
  }

  build() {
    LynxColumn({ style: { width: '100%', height: '100%', backgroundColor: '#F5F7FA' } }) {
      LynxScroll({ style: { width: '100%', height: '100%' }, scrollBar: BarState.Off }) {
        LynxColumn({ space: 16, style: { padding: { left: 16, right: 16, bottom: 20 }, width: '100%' } }) {
          this.buildQuickActions()

          LynxColumn({ space: 12 }) {
            ForEach(this.vaultItems, (item: VaultItem) => {
              this.buildVaultItem(item)
            }, (item: VaultItem) => item.key)
          }
        }
      }
    }
  }
}
