import { KeyStore, ImportedKey } from '../common/Stores';
import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import util from '@ohos.util';

@Entry
@Component
struct SettingsKeys {
  @State keyName: string = '';
  @State keyContent: string = '';
  @State keyPublic: string = '';
  @State keyPassphrase: string = '';
  @State exportPassword: string = '';
  @State importPassword: string = '';
  @State isExporting: boolean = false;
  @State isImporting: boolean = false;
  @State keyList: Array<ImportedKey> = [];

  private textEncoder: util.TextEncoder = util.TextEncoder.create();
  private textDecoder: util.TextDecoder = util.TextDecoder.create();

  aboutToAppear(): void {
    this.syncKeyList();
  }

  private syncKeyList(): void {
    this.keyList = [...KeyStore.list()];
  }

  private async saveManualKey(): Promise<void> {
    if (!this.keyName || !this.keyContent) {
      promptAction.showToast({ message: '请填写名称和私钥' });
      return;
    }
    KeyStore.importKey(this.keyName, this.keyContent, this.keyPublic, this.keyPassphrase);
    this.keyName = '';
    this.keyContent = '';
    this.keyPublic = '';
    this.keyPassphrase = '';
    this.syncKeyList();
    promptAction.showToast({ message: '密钥已保存' });
  }

  private async exportKeys(): Promise<void> {
    if (this.isExporting) return;
    if (this.keyList.length === 0) {
      promptAction.showToast({ message: '暂无密钥可导出' });
      return;
    }
    if (!this.exportPassword) {
      promptAction.showToast({ message: '请输入导出密码' });
      return;
    }
    this.isExporting = true;
    try {
      const backupContent = KeyStore.exportEncrypted(this.exportPassword);
      const documentPicker = new picker.DocumentViewPicker();
      const fileName = `kessh_keys_${new Date().getTime()}.json`;
      const saveResult = await documentPicker.save({ newFileNames: [fileName] });
      if (saveResult && saveResult.length > 0) {
        const saveUri = saveResult[0];
        const file = fileIo.openSync(saveUri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE);
        const encoded = this.textEncoder.encodeInto(backupContent);
        fileIo.writeSync(file.fd, encoded.buffer);
        fileIo.closeSync(file);
        promptAction.showToast({ message: `已导出到 ${fileName}` });
      } else {
        promptAction.showToast({ message: '已取消导出' });
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      promptAction.showToast({ message: `导出失败: ${message}` });
    } finally {
      this.isExporting = false;
    }
  }

  private async importKeys(): Promise<void> {
    if (this.isImporting) return;
    if (!this.importPassword) {
      promptAction.showToast({ message: '请输入导入密码' });
      return;
    }
    this.isImporting = true;
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.select({ maxSelectNumber: 1 });
      if (!result || result.length === 0) {
        promptAction.showToast({ message: '已取消导入' });
        return;
      }
      const uri = result[0];
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(uri);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file);
      const content = this.textDecoder.decodeWithStream(new Uint8Array(buffer), { stream: false });
      const stats = KeyStore.importEncrypted(content, this.importPassword);
      this.syncKeyList();
      promptAction.showToast({ message: `导入完成: 新增${stats.imported}条, 跳过${stats.skipped}条` });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      promptAction.showToast({ message: `导入失败: ${message}` });
    } finally {
      this.isImporting = false;
    }
  }

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
        Column({ space: 16 }) {
          Column({ space: 12 }) {
            Text('手动添加密钥')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .width('100%')

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
              .onClick((): void => { this.saveManualKey(); })
          }
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(16)

          Column({ space: 12 }) {
            Text('密钥备份（加密导出）')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .width('100%')
            Text('使用自定义密码对所有密钥进行AES加密后导出，请务必牢记该密码。')
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            TextInput({ placeholder: '导出密码', text: this.exportPassword })
              .type(InputType.Password)
              .onChange((v: string): void => { this.exportPassword = v })
            Button(this.isExporting ? '导出中...' : '导出密钥')
              .type(ButtonType.Normal)
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .borderRadius(24)
              .enabled(!this.isExporting)
              .opacity(this.isExporting ? 0.6 : 1)
              .onClick((): void => { this.exportKeys(); })
          }
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(16)

          Column({ space: 12 }) {
            Text('从备份恢复密钥')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .width('100%')
            Text('选择先前导出的密钥文件并输入当时设置的密码，即可批量导入。')
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            TextInput({ placeholder: '导入密码', text: this.importPassword })
              .type(InputType.Password)
              .onChange((v: string): void => { this.importPassword = v })
            Button(this.isImporting ? '导入中...' : '导入密钥')
              .type(ButtonType.Normal)
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
              .fontColor(Color.White)
              .borderRadius(24)
              .enabled(!this.isImporting)
              .opacity(this.isImporting ? 0.6 : 1)
              .onClick((): void => { this.importKeys(); })
          }
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(16)
        }
        .padding(16)
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 列表
      if (this.keyList.length > 0) {
        List() {
          ForEach(this.keyList, (k: ImportedKey) => {
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
                  .type(ButtonType.Capsule)
                  .height(28)
                  .fontSize(12)
                  .backgroundColor($r('sys.color.ohos_id_color_warning'))
                  .fontColor(Color.White)
                  .onClick((): void => { 
                    promptAction.showDialog({
                      title: '确认删除',
                      message: `确定要删除密钥 "${k.name}" 吗？此操作不可恢复。`,
                      buttons: [
                        { text: '取消', color: $r('sys.color.ohos_id_color_text_secondary') },
                        { text: '删除', color: $r('sys.color.ohos_id_color_warning') }
                      ]
                    }).then((result) => {
                      if (result.index === 1) {
                        KeyStore.remove(k.id);
                        this.syncKeyList();
                        promptAction.showToast({ message: '已删除' });
                      }
                    });
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
          Text('🔑')
            .fontSize(48)
          Text('暂无密钥')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
          Text('可通过手动添加或从备份恢复密钥')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%')
        .padding({ top: 48, bottom: 48 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
