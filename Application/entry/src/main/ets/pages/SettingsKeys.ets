import { KeyStore, ImportedKey } from '../common/Stores';
import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';

@Entry
@Component
export default struct SettingsKeys {
  @State keyName: string = '';
  @State keyContent: string = '';
  @State keyPublic: string = '';
  @State keyPassphrase: string = '';

  build() {
    Column() {
      // 顶部：状态栏占位 + 标题栏（返回）
      Blank().height(36).width('100%')
      Row() {
        Button('<')
          .type(ButtonType.Normal)
          .height(36)
          .width(36)
          .backgroundColor('#0F000000')
          .borderRadius(18)
          .onClick((): void => router.back())
        Text('密钥管理')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
        Blank().layoutWeight(1)
      }
      .height(56)
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 表单
      Column({ space: 8 }) {
        Text('导入密钥')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 16, right: 16, top: 8 })

        TextInput({ placeholder: '密钥名称', text: this.keyName })
          .onChange((v: string): void => { this.keyName = v })
        TextArea({ placeholder: '粘贴私钥(PEM)', text: this.keyContent })
          .onChange((v: string): void => { this.keyContent = v })
        TextArea({ placeholder: '粘贴公钥(可选)', text: this.keyPublic })
          .onChange((v: string): void => { this.keyPublic = v })
        TextInput({ placeholder: '口令(可选)', text: this.keyPassphrase })
          .type(InputType.Password)
          .onChange((v: string): void => { this.keyPassphrase = v })

        Row() {
          Blank().layoutWeight(1)
          Button('保存密钥')
            .type(ButtonType.Normal)
            .height(44)
            .backgroundColor('#222222')
            .fontColor(Color.White)
            .borderRadius(12)
            .onClick((): void => {
              if (!this.keyName || !this.keyContent) { promptAction.showToast({ message: '请填写名称和私钥' }); return; }
              KeyStore.importKey(this.keyName, this.keyContent, this.keyPublic, this.keyPassphrase);
              this.keyName = ''; this.keyContent = ''; this.keyPublic = ''; this.keyPassphrase = '';
              promptAction.showToast({ message: '密钥已保存' });
            })
        }
        .padding({ left: 16, right: 16 })
      }

      // 列表
      if (KeyStore.list().length > 0) {
        List() {
          ForEach(KeyStore.list(), (k: ImportedKey) => {
            ListItem() {
              Row() {
                Column({ space: 4 }) {
                  Text(k.name).fontSize(14)
                  if (k.fingerprint) {
                    Text(`指纹: ${k.fingerprint.slice(0, 32)}…`)
                      .fontSize(10)
                      .fontColor(Color.Grey)
                  }
                }
                Blank().layoutWeight(1)
                Button('删除')
                  .type(ButtonType.Normal)
                  .height(32)
                  .backgroundColor('#0F000000')
                  .borderRadius(8)
                  .onClick((): void => { KeyStore.remove(k.id); })
              }
              .padding({ left: 12, right: 12 })
              .height(44)
            }
          }, (k: ImportedKey) => k.id.toString())
        }
        .divider({ strokeWidth: 1, color: '#11000000' })
        .edgeEffect(EdgeEffect.None)
      } else {
        Text('暂无密钥')
          .fontSize(12)
          .fontColor(Color.Grey)
          .margin({ left: 16, right: 16, top: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
