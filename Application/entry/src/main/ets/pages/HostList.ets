import { ConnectionStore, ConnectionRecord } from '../common/Stores';
import { promptAction, router } from '@kit.ArkUI';
import { LynxBlank, LynxButton, LynxColumn, LynxList, LynxListItem, LynxRow, LynxText } from '../common/LynxUI';
import { getLynxPalette, LynxPalette } from '../common/LynxTheme';
import { SettingsStore } from '../common/Stores';

@Entry
@Component
export default struct HostList {
  @StorageLink(SettingsStore.DARK_MODE_KEY) darkMode: boolean = SettingsStore.darkMode;
  @State hosts: Array<ConnectionRecord> = [];

  aboutToAppear(): void {
    this.refreshHosts();
  }

  private refreshHosts(): void {
    this.hosts = ConnectionStore.list();
  }

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

  build() {
    Column() {
      // Top bar
      LynxBlank({ style: { height: 36, width: '100%' } })
      LynxRow({ style: { height: 56, width: '100%', padding: { left: 16, right: 16 } } }) {
        LynxButton({
          label: '<',
          style: { height: 36, width: 36, backgroundColor: this.getPalette().card, borderRadius: 18 },
          onClick: (): void => router.back(),
        })
        LynxText({ content: '主机列表', style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 12 }, fontColor: this.getPalette().primaryText } })
        LynxBlank({ style: { layoutWeight: 1 } })
      }

      if (this.hosts.length > 0) {
        LynxList({ divider: { strokeWidth: 1, color: '#11000000' }, edgeEffect: EdgeEffect.None }) {
          ForEach(this.hosts, (item: ConnectionRecord) => {
            LynxListItem({ style: { padding: { left: 16, right: 16, top: 8, bottom: 8 } } }) {
              LynxRow({
                style: { padding: 16, backgroundColor: this.getPalette().surface, borderRadius: 16 },
                onTap: (): void => { this.connect(item); }
              }) {
                LynxColumn({ space: 4 }) {
                  LynxText({ content: item.name, style: { fontSize: 16, fontWeight: FontWeight.Medium, fontColor: this.getPalette().primaryText } })
                  LynxText({ content: `${item.username} • ${item.time}`, style: { fontSize: 13, fontColor: this.getPalette().secondaryText } })
                }
                LynxBlank({ style: { layoutWeight: 1 } })
                LynxText({ content: '连接', style: { fontSize: 14, fontColor: this.getPalette().accent } })
              }
            }
          }, (item: ConnectionRecord) => item.id.toString())
        }
      } else {
        LynxColumn({ style: { layoutWeight: 1, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center } }) {
          LynxText({ content: '暂无主机', style: { fontSize: 16, fontColor: this.getPalette().secondaryText } })
          LynxButton({
            label: '添加主机',
            style: { margin: { top: 16 }, width: 120, height: 40, backgroundColor: this.getPalette().accent, fontColor: Color.White, borderRadius: 20 },
            onClick: (): void => { ConnectionStore.currentDraft = null; router.pushUrl({ url: 'pages/AddHost' }); }
          })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageBackground)
  }
}
