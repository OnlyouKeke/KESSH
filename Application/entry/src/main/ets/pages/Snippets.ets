import { SnippetStore, Snippet } from '../common/Stores';
import { router, promptAction } from '@kit.ArkUI';
import { LynxBlank, LynxButton, LynxColumn, LynxList, LynxListItem, LynxRow, LynxText, LynxTextInput } from '../common/LynxUI';
import { getLynxPalette, LynxPalette } from '../common/LynxTheme';
import { SettingsStore } from '../common/Stores';

@Entry
@Component
export default struct Snippets {
  @State newTitle: string = '';
  @State newCommand: string = '';
  @State snippets: Array<Snippet> = [];
  @StorageLink(SettingsStore.DARK_MODE_KEY) darkMode: boolean = SettingsStore.darkMode;

  aboutToAppear(): void {
    this.refreshSnippets();
  }

  private refreshSnippets(): void {
    this.snippets = SnippetStore.list();
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

  private addSnippet(): void {
    const title = this.newTitle.trim();
    const command = this.newCommand.trim();
    if (title && command) {
      SnippetStore.add(title, command);
      this.newTitle = '';
      this.newCommand = '';
      this.refreshSnippets();
      promptAction.showToast({ message: '已添加' });
    }
  }

  private removeSnippet(id: number): void {
    SnippetStore.remove(id);
    this.refreshSnippets();
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
        LynxText({ content: '代码片段', style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 12 }, fontColor: this.getPalette().primaryText } })
        LynxBlank({ style: { layoutWeight: 1 } })
      }

      // Add new
      LynxColumn({ space: 12, style: { padding: 16, backgroundColor: this.getPalette().surface, margin: 16, borderRadius: 16 } }) {
        LynxTextInput({ placeholder: '标题', text: this.newTitle, style: { height: 40, backgroundColor: this.getPalette().pageBackground, borderRadius: 8, padding: { left: 12 } }, onChange: (v: string): void => { this.newTitle = v; } })
        LynxTextInput({ placeholder: '命令', text: this.newCommand, style: { height: 40, backgroundColor: this.getPalette().pageBackground, borderRadius: 8, padding: { left: 12 } }, onChange: (v: string): void => { this.newCommand = v; } })
        LynxButton({
          label: '添加片段',
          style: { height: 40, backgroundColor: this.getPalette().accent, fontColor: Color.White, borderRadius: 12 },
          onClick: (): void => { this.addSnippet(); }
        })
      }

      // List
      LynxList({ divider: { strokeWidth: 1, color: '#11000000' }, edgeEffect: EdgeEffect.None }) {
        ForEach(this.snippets, (item: Snippet) => {
          LynxListItem({ style: { padding: { left: 16, right: 16, top: 8, bottom: 8 } } }) {
            LynxRow({ style: { padding: 16, backgroundColor: this.getPalette().surface, borderRadius: 16 } }) {
              LynxColumn({ space: 4 }) {
                LynxText({ content: item.title, style: { fontSize: 16, fontWeight: FontWeight.Medium, fontColor: this.getPalette().primaryText } })
                LynxText({ content: item.command, style: { fontSize: 13, fontFamily: 'monospace', fontColor: this.getPalette().primaryText, backgroundColor: '#10000000', padding: 4, borderRadius: 4 } })
              }
              LynxBlank({ style: { layoutWeight: 1 } })
              LynxButton({
                label: '删除',
                style: { height: 32, backgroundColor: '#0F000000', borderRadius: 8 },
                onClick: (): void => { this.removeSnippet(item.id); }
              })
            }
          }
        }, (item: Snippet) => item.id.toString())
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageBackground)
  }
}
