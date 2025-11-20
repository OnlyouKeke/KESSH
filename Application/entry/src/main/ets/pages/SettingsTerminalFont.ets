import { SettingsStore } from '../common/Stores';
import { promptAction, router } from '@kit.ArkUI';
import { ensureTerminalFontsRegistered, getTerminalFontOptions, resolveFontFamily, TerminalFontKey, TerminalFontOption } from '../common/TerminalFonts';

@Entry
@Component
export struct SettingsTerminalFont {
  @State selectedFont: TerminalFontKey = SettingsStore.terminalFontFamily as TerminalFontKey;
  @State fontSizeInput: string = SettingsStore.terminalFontSize.toString();
  @State saving: boolean = false;

  aboutToAppear(): void {
    ensureTerminalFontsRegistered();
    this.selectedFont = SettingsStore.terminalFontFamily as TerminalFontKey;
    this.fontSizeInput = SettingsStore.terminalFontSize.toString();
  }

  private parseFontSize(value: string): number {
    const parsed = parseInt(value, 10);
    return Number.isNaN(parsed) ? SettingsStore.terminalFontSize : parsed;
  }

  private async saveFontSize(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      const size = this.parseFontSize(this.fontSizeInput);
      await SettingsStore.setTerminalFontSize(size);
      promptAction.showToast({ message: '字体大小已保存' });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      promptAction.showToast({ message: `保存失败: ${message}` });
    } finally {
      this.saving = false;
    }
  }

  private async selectFont(key: TerminalFontKey): Promise<void> {
    if (this.selectedFont === key) {
      return;
    }
    try {
      await SettingsStore.setTerminalFontFamily(key);
      this.selectedFont = key;
      promptAction.showToast({ message: '字体已更新' });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      promptAction.showToast({ message: `更新失败: ${message}` });
    }
  }

  build() {
    Column() {
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

        Text('终端字体')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 4 })
        Blank().layoutWeight(1)
      }
      .height(56)
      .width('100%')
      .padding({ left: 8, right: 16 })

      Scroll() {
        Column({ space: 24 }) {
          // 当前选中字体的预览
          Column({ space: 12 }) {
            Text('当前字体预览')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            Column() {
              Text('0O iIl1 ~-= <>[] {}() 0123456789')
                .fontSize(this.parseFontSize(this.fontSizeInput))
                .fontFamily(resolveFontFamily(this.selectedFont))
              Text('ssh root@192.168.1.100 -p 22')
                .fontSize(this.parseFontSize(this.fontSizeInput))
                .fontFamily(resolveFontFamily(this.selectedFont))
                .margin({ top: 4 })
              Text('export PATH=$PATH:/usr/local/bin')
                .fontSize(this.parseFontSize(this.fontSizeInput))
                .fontFamily(resolveFontFamily(this.selectedFont))
                .margin({ top: 4 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
            .borderRadius(16)
          }

          Column({ space: 12 }) {
            Text('字体列表')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            List() {
              ForEach(getTerminalFontOptions(), (option: TerminalFontOption) => {
                ListItem() {
                  Column() {
                    Row() {
                      Column({ space: 4 }) {
                        Text(option.label)
                          .fontSize(16)
                          .fontWeight(FontWeight.Medium)
                        Text(option.description)
                          .fontSize(12)
                          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)
                      Text(this.selectedFont === option.key ? '✓' : '')
                        .fontSize(18)
                        .fontColor($r('sys.color.ohos_id_color_emphasize'))
                    }
                    .padding({ top: 12, bottom: 8, left: 4, right: 4 })
                    .width('100%')
                    
                    // 每个字体的预览示例
                    Column() {
                      Text('0O iIl1 ~-= <> {}() 123456')
                        .fontSize(13)
                        .fontFamily(option.family)
                        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    }
                    .width('100%')
                    .padding({ left: 4, right: 4, bottom: 8 })
                  }
                  .width('100%')
                }
                .onClick((): void => { this.selectFont(option.key); })
              }, (option: TerminalFontOption) => option.key)
            }
            .divider({
              strokeWidth: 1,
              color: $r('sys.color.ohos_id_color_list_separator'),
              startMargin: 12,
              endMargin: 12
            })
            .edgeEffect(EdgeEffect.Spring)
          }

          Column({ space: 8 }) {
            Text('字体大小')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            TextInput({ text: this.fontSizeInput, placeholder: '例如 14' })
              .type(InputType.Number)
              .onChange((value: string): void => { this.fontSizeInput = value; })
            Button(this.saving ? '保存中...' : '保存大小')
              .type(ButtonType.Normal)
              .height(44)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
              .fontColor(Color.White)
              .borderRadius(22)
              .enabled(!this.saving)
              .onClick((): void => { this.saveFontSize(); })
          }
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 32 })
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
