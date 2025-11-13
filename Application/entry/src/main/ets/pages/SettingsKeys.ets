import { KeyStore, ImportedKey } from '../common/Stores';
import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct SettingsKeys {
  @State keyName: string = '';
  @State keyContent: string = '';
  @State keyPublic: string = '';
  @State keyPassphrase: string = '';

  build() {
    Column() {
      // 顶部：状态栏占位 + 标题栏（返回）
      Row() {
        Text('<')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick((): void => {
            router.back();
          })
        
        Text('密钥管理')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 4 })
        Blank().layoutWeight(1)
      }
      .height(56)
      .width('100%')
      .padding({ left: 8, right: 16 })

      // 表单
      Scroll() {
        Column({ space: 12 }) {
          Text('导入密钥')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 8 })

          TextInput({ placeholder: '密钥名称', text: this.keyName })
            .onChange((v: string): void => { this.keyName = v })
          
          TextArea({ placeholder: '粘贴私钥(PEM)', text: this.keyContent })
            .height(120)
            .onChange((v: string): void => { this.keyContent = v })
          
          TextArea({ placeholder: '粘贴公钥(可选)', text: this.keyPublic })
            .height(80)
            .onChange((v: string): void => { this.keyPublic = v })
          
          TextInput({ placeholder: '口令(可选)', text: this.keyPassphrase })
            .type(InputType.Password)
            .onChange((v: string): void => { this.keyPassphrase = v })

          Button('保存密钥')
            .type(ButtonType.Normal)
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
            .fontColor(Color.White)
            .borderRadius(24)
            .margin({ top: 16 })
            .onClick((): void => {
              if (!this.keyName || !this.keyContent) { 
                promptAction.showToast({ message: '请填写名称和私钥' }); 
                return; 
              }
              KeyStore.importKey(this.keyName, this.keyContent, this.keyPublic, this.keyPassphrase);
              this.keyName = ''; 
              this.keyContent = ''; 
              this.keyPublic = ''; 
              this.keyPassphrase = '';
              promptAction.showToast({ message: '密钥已保存' });
            })
        }
        .padding(16)
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 列表
      if (KeyStore.list().length > 0) {
        List() {
          ForEach(KeyStore.list(), (k: ImportedKey) => {
            ListItem() {
              Row() {
                Column({ space: 4 }) {
                  Text(k.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                  if (k.fingerprint) {
                    Text(`指纹: ${k.fingerprint.slice(0, 32)}…`)
                      .fontSize(12)
                      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                
                Button('删除')
                  .type(ButtonType.Normal)
                  .height(32)
                  .fontSize(14)
                  .backgroundColor($r('sys.color.ohos_id_color_warning'))
                  .fontColor(Color.White)
                  .borderRadius(16)
                  .onClick((): void => { 
                    KeyStore.remove(k.id);
                    promptAction.showToast({ message: '已删除' });
                  })
              }
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .width('100%')
            }
          }, (k: ImportedKey) => k.id.toString())
        }
        .divider({ 
          strokeWidth: 1, 
          color: $r('sys.color.ohos_id_color_list_separator'),
          startMargin: 16,
          endMargin: 16
        })
        .edgeEffect(EdgeEffect.Spring)
      } else {
        Column({ space: 12 }) {
          Text('暂无密钥')
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Text('请在上方输入框中导入SSH密钥')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%')
        .padding({ top: 32 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
