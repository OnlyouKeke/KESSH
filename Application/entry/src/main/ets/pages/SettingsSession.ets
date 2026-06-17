import { SettingsStore } from '../common/Stores';
import { SSHEngine } from '../common/SSHEngine';
import { promptAction, router } from '@kit.ArkUI';

@Entry
@Component
export struct SettingsSession {
  @State intervalInput: string = SettingsStore.sessionKeepaliveInterval.toString();
  @State attemptsInput: string = SettingsStore.sessionKeepaliveAttempts.toString();
  @State saving: boolean = false;

  aboutToAppear(): void {
    this.intervalInput = SettingsStore.sessionKeepaliveInterval.toString();
    this.attemptsInput = SettingsStore.sessionKeepaliveAttempts.toString();
  }

  private parseValue(value: string, fallback: number, min: number, max: number): number {
    if (!/^\d+$/.test(value.trim())) {
      return fallback;
    }
    const parsed = parseInt(value, 10);
    if (Number.isNaN(parsed)) {
      return fallback;
    }
    if (parsed < min) {
      return min;
    }
    if (parsed > max) {
      return max;
    }
    return parsed;
  }

  private async saveSettings(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      const interval = this.parseValue(this.intervalInput, SettingsStore.sessionKeepaliveInterval, 5, 3600);
      const attempts = this.parseValue(this.attemptsInput, SettingsStore.sessionKeepaliveAttempts, 1, 10);
      await SettingsStore.setSessionKeepaliveInterval(interval);
      await SettingsStore.setSessionKeepaliveAttempts(attempts);
      SSHEngine.configureKeepalive(SettingsStore.sessionKeepaliveInterval, SettingsStore.sessionKeepaliveAttempts);
      promptAction.showToast({ message: '会话设置已保存' });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      promptAction.showToast({ message: `保存失败: ${message}` });
    } finally {
      this.saving = false;
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

        Text('会话设置')
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
          Column({ space: 8 }) {
            Text('保活时间间隔（秒）')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            TextInput({ text: this.intervalInput, placeholder: '建议 10-300' })
              .type(InputType.Number)
              .onChange((value: string): void => { this.intervalInput = value; })
            Text('每次保活会在设置的间隔内发送 SSH keepalive 请求，避免会话被服务器断开。')
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }

          Column({ space: 8 }) {
            Text('失败后重试次数')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
            TextInput({ text: this.attemptsInput, placeholder: '建议 1-5 次' })
              .type(InputType.Number)
              .onChange((value: string): void => { this.attemptsInput = value; })
            Text('连续多次保活失败后将提示并自动断开连接。')
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }

          Button(this.saving ? '保存中...' : '保存设置')
            .type(ButtonType.Normal)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
            .fontColor(Color.White)
            .borderRadius(24)
            .enabled(!this.saving)
            .onClick((): void => { this.saveSettings(); })
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
