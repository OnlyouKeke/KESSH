import { KeyStore, ImportedKey } from '../common/Stores';
import { promptAction, router } from '@kit.ArkUI';
import { LynxBlank, LynxButton, LynxColumn, LynxList, LynxListItem, LynxRow, LynxText, LynxTextArea, LynxTextInput } from '../common/LynxUI';

@Entry
@Component
export default struct SettingsKeys {
  @State keyName: string = '';
  @State keyContent: string = '';
  @State keyPublic: string = '';
  @State keyPassphrase: string = '';

  build() {
    LynxColumn({ style: { width: '100%', height: '100%' } }) {
      // Top bar
      LynxBlank({ style: { height: 36, width: '100%' } })
      LynxRow({ style: { height: 56, width: '100%', padding: { left: 16, right: 16 } } }) {
        LynxButton({
          label: '<',
          style: { height: 36, width: 36, backgroundColor: '#0F000000', borderRadius: 18 },
          onClick: (): void => router.back(),
        })
        LynxText({ content: 'Key Management', style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 12 } } })
        LynxBlank({ style: { layoutWeight: 1 } })
      }

      // Form
      LynxRow() {
        LynxColumn({ space: 8 }) {
          LynxText({ content: 'Import key', style: { fontSize: 18, fontWeight: FontWeight.Medium, margin: { left: 16, right: 16, top: 8 } } })

          LynxTextInput({ placeholder: 'Key name', text: this.keyName, onChange: (v: string): void => { this.keyName = v } })
          LynxTextArea({ placeholder: 'Paste private key (PEM)', text: this.keyContent, onChange: (v: string): void => { this.keyContent = v } })
          LynxTextArea({ placeholder: 'Paste public key (optional)', text: this.keyPublic, onChange: (v: string): void => { this.keyPublic = v } })
          LynxTextInput({ placeholder: 'Passphrase (optional)', text: this.keyPassphrase, type: InputType.Password, onChange: (v: string): void => { this.keyPassphrase = v } })

          LynxRow({ style: { padding: { left: 16, right: 16 } } }) {
            LynxBlank({ style: { layoutWeight: 1 } })
            LynxButton({
              label: 'Save key',
              style: { height: 44, backgroundColor: '#222222', fontColor: Color.White, borderRadius: 12 },
              onClick: (): void => {
                if (!this.keyName || !this.keyContent) {
                  promptAction.showToast({ message: 'Please fill name and private key' });
                  return;
                }
                KeyStore.importKey(this.keyName, this.keyContent, this.keyPublic, this.keyPassphrase);
                this.keyName = '';
                this.keyContent = '';
                this.keyPublic = '';
                this.keyPassphrase = '';
                promptAction.showToast({ message: 'Saved' });
              }
            })
          }
        }
        .layoutWeight(1)
      }

      // List
      if (KeyStore.list().length > 0) {
        LynxList({ divider: { strokeWidth: 1, color: '#11000000' }, edgeEffect: EdgeEffect.None }) {
          ForEach(KeyStore.list(), (k: ImportedKey) => {
            LynxListItem({ style: { padding: { left: 12, right: 12 }, height: 44 } }) {
              LynxRow() {
                LynxColumn({ space: 4 }) {
                  LynxText({ content: k.name, style: { fontSize: 14 } })
                  if (k.fingerprint) {
                    LynxText({ content: `Fingerprint: ${k.fingerprint.slice(0, 32)}…`, style: { fontSize: 10, fontColor: Color.Grey } })
                  }
                }
                LynxBlank({ style: { layoutWeight: 1 } })
                LynxButton({
                  label: 'Delete',
                  style: { height: 32, backgroundColor: '#0F000000', borderRadius: 8 },
                  onClick: (): void => { KeyStore.remove(k.id); }
                })
              }
            }
          }, (k: ImportedKey) => k.id.toString())
        }
      } else {
        LynxText({ content: 'No keys yet', style: { fontSize: 12, fontColor: Color.Grey, margin: { left: 16, right: 16, top: 16 } } })
      }
    }
  }
}
