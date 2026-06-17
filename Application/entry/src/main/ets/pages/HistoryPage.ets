import { LynxBlank, LynxColumn, LynxRow, LynxScroll, LynxText } from '../common/LynxUI';
import { getLynxPalette, LynxPalette } from '../common/LynxTheme';
import { SettingsStore } from '../common/Stores';
import { ConnectionStore, ConnectionRecord } from '../common/Stores';
import { promptAction, router } from '@kit.ArkUI';

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
  @StorageLink(SettingsStore.DARK_MODE_KEY) darkMode: boolean = SettingsStore.darkMode;
  @State recentHistory: Array<ConnectionRecord> = [];

  aboutToAppear() {
    this.recentHistory = ConnectionStore.list().slice(0, 3);
  }

  private quickActions: Array<string> = ['📂', '🛡️', '🔔'];

  private vaultItems: Array<VaultItem> = [
    { key: 'hosts', title: '主机', subtitle: '管理 SSH 主机和保存的会话', icon: '💻' },
    { key: 'keys', title: '密钥管理', subtitle: '本地密钥与身份管理', icon: '🔑' },
    { key: 'snippets', title: '代码片段', subtitle: '复用常用命令', icon: '🧞' }
  ];

  private getPalette(): LynxPalette {
    const p = getLynxPalette(this.darkMode);
    if (p) return p;
    return {
      pageBackground: '#F5F7FA',
      surface: '#FFFFFFFF',
      card: '#10E7F0F5',
      primaryText: '#0F1115',
      secondaryText: '#6B7280',
      border: '#11000000',
      accent: '#1E7DD6'
    };
  }

  private connect(item: ConnectionRecord): void {
    if (item.authType === 'key') {
      promptAction.showToast({ message: '密钥认证暂未支持' });
      return;
    }
    const password = ConnectionStore.getPassword(item);
    if (!password) {
      promptAction.showToast({ message: '请输入密码后连接' });
      ConnectionStore.currentDraft = ConnectionStore.draftForPasswordInput(item);
      router.pushUrl({ url: 'pages/AddHost' });
      return;
    }
    ConnectionStore.currentDraft = ConnectionStore.draftFromRecord(item, password);
    router.pushUrl({ url: 'pages/Terminal' });
  }

  @Builder
  buildQuickActions() {
    LynxRow({ space: 12, style: { width: '100%', justifyContent: FlexAlign.SpaceBetween } }) {
      ForEach(this.quickActions, (icon: string, index: number) => {
        LynxColumn({
          style: {
            width: 64,
            height: 64,
            borderRadius: 18,
            backgroundColor: this.getPalette().card,
            justifyContent: FlexAlign.Center,
            alignItems: ItemAlign.Center
          }
        }) {
            LynxText({ content: icon, style: { fontSize: 20, fontColor: this.getPalette().primaryText } })
          }
      }, (icon: string, index: number) => index.toString())
    }
  }

  @Builder
  buildVaultItem(item: VaultItem) {
    LynxRow({
      style: { width: '100%', padding: { left: 16, right: 16, top: 14, bottom: 14 }, backgroundColor: this.getPalette().card, borderRadius: 18 },
      onTap: (): void => {
        if (item.key === 'hosts') router.pushUrl({ url: 'pages/HostList' });
        else if (item.key === 'keys') router.pushUrl({ url: 'pages/SettingsKeys' });
        else if (item.key === 'snippets') router.pushUrl({ url: 'pages/Snippets' });
      }
    }) {
      LynxText({ content: item.icon, style: { fontSize: 20, margin: { right: 12 }, fontColor: this.getPalette().primaryText } })

      LynxColumn({ space: 4 }) {
        LynxText({ content: item.title, style: { fontSize: 16, fontWeight: FontWeight.Medium, fontColor: this.getPalette().primaryText } })
        LynxText({ content: item.subtitle, style: { fontSize: 13, fontColor: this.getPalette().secondaryText } })
      }

      LynxBlank({ style: { layoutWeight: 1 } })

      LynxRow({ space: 8 }) {
        if (item.badge) {
          LynxText({
            content: item.badge,
            style: {
              fontSize: 12,
              fontColor: '#ffffff',
              backgroundColor: this.getPalette().accent,
              padding: { left: 8, right: 8, top: 4, bottom: 4 },
              borderRadius: 12
            }
          })
        }
        LynxText({ content: '>', style: { fontSize: 18, fontColor: this.getPalette().secondaryText } })
      }
    }
  }

  build() {
    Column() {
      LynxScroll({ style: { width: '100%', height: '100%', backgroundColor: this.getPalette().pageBackground }, scrollBar: BarState.Off }) {
        LynxColumn({ space: 16, style: { padding: { left: 16, right: 16, bottom: 20 }, width: '100%' } }) {

          if (this.recentHistory.length > 0) {
            LynxColumn({ space: 8 }) {
              LynxText({ content: '最近连接', style: { fontSize: 18, fontWeight: FontWeight.Bold, fontColor: this.getPalette().primaryText } })
              ForEach(this.recentHistory, (item: ConnectionRecord) => {
                LynxRow({
                  style: { padding: 12, backgroundColor: this.getPalette().surface, borderRadius: 12 },
                  onTap: (): void => { this.connect(item); }
                }) {
                  LynxColumn({ space: 4 }) {
                    LynxText({ content: item.name, style: { fontSize: 14, fontWeight: FontWeight.Medium, fontColor: this.getPalette().primaryText } })
                    LynxText({ content: item.time, style: { fontSize: 12, fontColor: this.getPalette().secondaryText } })
                  }
                  LynxBlank({ style: { layoutWeight: 1 } })
                  LynxText({ content: '🚀', style: { fontSize: 16 } })
                }
              }, (item: ConnectionRecord) => item.id.toString())
            }
          }

          LynxColumn({ space: 12 }) {
            LynxText({ content: '资产管理', style: { fontSize: 18, fontWeight: FontWeight.Bold, fontColor: this.getPalette().primaryText } })
            ForEach(this.vaultItems, (item: VaultItem) => {
              this.buildVaultItem(item)
            }, (item: VaultItem) => item.key)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
