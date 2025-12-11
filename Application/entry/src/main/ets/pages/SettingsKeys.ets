import { KeyStore, ImportedKey } from '../common/Stores';
import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
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
      // 顶部：状态栏占位 + 标题栏（返回）
      LynxBlank({ style: { height: 36, width: '100%' } })
      LynxRow({ style: { height: 56, width: '100%', padding: { left: 16, right: 16 } } }) {
        LynxButton({
          label: '<',
          style: { height: 36, width: 36, backgroundColor: '#0F000000', borderRadius: 18 },
          onClick: (): void => router.back(),
        })
        LynxText({ content: '密钥管理', style: { fontSize: 24, fontWeight: FontWeight.Bold, margin: { left: 12 } } })
        LynxBlank({ style: { layoutWeight: 1 } })
      }

      // 表单
      LynxColumn({ space: 8 }) {
        LynxText({ content: '导入密钥', style: { fontSize: 18, fontWeight: FontWeight.Medium, margin: { left: 16, right: 16, top: 8 } } })

        LynxTextInput({ placeholder: '密钥名称', text: this.keyName, onChange: (v: string): void => { this.keyName = v } })
        LynxTextArea({ placeholder: '粘贴私钥(PEM)', text: this.keyContent, onChange: (v: string): void => { this.keyContent = v } })
        LynxTextArea({ placeholder: '粘贴公钥(可选)', text: this.keyPublic, onChange: (v: string): void => { this.keyPublic = v } })
        LynxTextInput({ placeholder: '口令(可选)', text: this.keyPassphrase, type: InputType.Password, onChange: (v: string): void => { this.keyPassphrase = v } })

        LynxRow({ style: { padding: { left: 16, right: 16 } } }) {
          LynxBlank({ style: { layoutWeight: 1 } })
          LynxButton({
            label: '保存密钥',
            style: { height: 44, backgroundColor: '#222222', fontColor: Color.White, borderRadius: 12 },
            onClick: (): void => {
              if (!this.keyName || !this.keyContent) { promptAction.showToast({ message: '请填写名称和私钥' }); return; }
              KeyStore.importKey(this.keyName, this.keyContent, this.keyPublic, this.keyPassphrase);
              this.keyName = ''; this.keyContent = ''; this.keyPublic = ''; this.keyPassphrase = '';
              promptAction.showToast({ message: '密钥已保存' });
            }
          })
        }
      }

      // 列表
      if (KeyStore.list().length > 0) {
        LynxList({ divider: { strokeWidth: 1, color: '#11000000' }, edgeEffect: EdgeEffect.None }) {
          ForEach(KeyStore.list(), (k: ImportedKey) => {
            LynxListItem({ style: { padding: { left: 12, right: 12 }, height: 44 } }) {
              LynxRow() {
                LynxColumn({ space: 4 }) {
                  LynxText({ content: k.name, style: { fontSize: 14 } })
                  if (k.fingerprint) {
                    LynxText({ content: `指纹: ${k.fingerprint.slice(0, 32)}…`, style: { fontSize: 10, fontColor: Color.Grey } })
                  }
                }
                LynxBlank({ style: { layoutWeight: 1 } })
                LynxButton({
                  label: '删除',
                  style: { height: 32, backgroundColor: '#0F000000', borderRadius: 8 },
                  onClick: (): void => { KeyStore.remove(k.id); }
                })
              }
            }
          }, (k: ImportedKey) => k.id.toString())
        }
      } else {
        LynxText({ content: '暂无密钥', style: { fontSize: 12, fontColor: Color.Grey, margin: { left: 16, right: 16, top: 16 } } })
      }
    }
  }
}
