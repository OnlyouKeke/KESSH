import { ConnectionStore, ConnectionDraft } from '../common/Stores';
import { router, promptAction } from '@kit.ArkUI';
import { LynxBlank, LynxButton, LynxColumn, LynxRow, LynxText, LynxTextInput } from '../common/LynxUI';
import { getLynxPalette, LynxPalette } from '../common/LynxTheme';
import { SettingsStore } from '../common/Stores';

@Entry
@Component
export default struct AddHost {
  @State host: string = '';
  @State port: string = '22';
  @State username: string = '';
  @State password: string = '';
  @State editingId: number = -1;
  @State isEditing: boolean = false;
  @StorageLink(SettingsStore.DARK_MODE_KEY) darkMode: boolean = SettingsStore.darkMode;

  aboutToAppear(): void {
    const draft = ConnectionStore.currentDraft;
    if (!draft) {
      return;
    }
    this.host = draft.host || '';
    this.port = draft.port || '22';
    this.username = draft.username || '';
    this.password = draft.password || '';
    this.isEditing = draft.isEditing === true;
    this.editingId = draft.editingId ?? -1;
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

  private saveAndConnect(): void {
    const draft: ConnectionDraft = {
      host: this.host,
      port: this.port,
      username: this.username,
      password: this.password,
      isEditing: this.isEditing,
      editingId: this.editingId >= 0 ? this.editingId : undefined
    };
    const validation = ConnectionStore.validateDraft(draft);
    if (validation) {
      promptAction.showToast({ message: validation });
      return;
    }
    if (!this.password || this.password.length === 0) {
      promptAction.showToast({ message: '请输入密码后连接' });
      return;
    }

    const normalized = ConnectionStore.normalizeDraft(draft);
    normalized.password = this.password;
    try {
      const record = ConnectionStore.addFromDraft(normalized, 'password');
      if (SettingsStore.savePassword) {
        ConnectionStore.savePassword(record, this.password);
      }
      ConnectionStore.currentDraft = normalized;
      router.pushUrl({ url: 'pages/Terminal' });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      promptAction.showToast({ message });
    }
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
        LynxText({ content: this.isEditing ? '输入密码' : '添加主机', style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 12 }, fontColor: this.getPalette().primaryText } })
        LynxBlank({ style: { layoutWeight: 1 } })
      }

      // Form
      LynxColumn({ space: 16, style: { padding: { left: 16, right: 16, top: 16 } } }) {
        LynxTextInput({
          placeholder: '主机地址 (IP 或域名)',
          text: this.host,
          style: { height: 48, padding: { left: 16, right: 16 }, backgroundColor: this.getPalette().surface, borderRadius: 14 },
          onChange: (v: string): void => { this.host = v; }
        })

        LynxRow({ space: 12 }) {
          LynxTextInput({
            placeholder: '端口',
            text: this.port,
            type: InputType.Number,
            style: { height: 48, padding: { left: 16, right: 16 }, width: 100, backgroundColor: this.getPalette().surface, borderRadius: 14 },
            onChange: (v: string): void => { this.port = v; }
          })
          LynxTextInput({
            placeholder: '用户名',
            text: this.username,
            style: { height: 48, padding: { left: 16, right: 16 }, layoutWeight: 1, backgroundColor: this.getPalette().surface, borderRadius: 14 },
            onChange: (v: string): void => { this.username = v; }
          })
        }

        LynxTextInput({
          placeholder: '密码',
          text: this.password,
          type: InputType.Password,
          style: { height: 48, padding: { left: 16, right: 16 }, backgroundColor: this.getPalette().surface, borderRadius: 14 },
          onChange: (v: string): void => { this.password = v; }
        })

        LynxButton({
          label: '保存并连接',
          style: { height: 50, backgroundColor: this.getPalette().accent, fontColor: Color.White, borderRadius: 16 },
          onClick: (): void => { this.saveAndConnect(); }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageBackground)
  }
}
