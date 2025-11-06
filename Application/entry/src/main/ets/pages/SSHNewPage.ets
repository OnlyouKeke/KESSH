import { promptAction, router } from '@kit.ArkUI';
import hilog from '@ohos.hilog';
import { Logger, SettingsStore, ConnectionStore, KeyStore, ImportedKey, AuthType, ConnectionDraft } from '../common/Stores';
import { SSHEngine } from '../common/NativeSSH';

const LOG_DOMAIN = 0xD15A;
const LOG_TAG = 'SSHNewPage';

@Entry
@Component
export default struct SSHNewPage {
  @State host: string = '';
  @State port: string = '22';
  @State username: string = '';
  @State password: string = '';
  @State selectedKeyId: number = -1;
  @State authType: string = 'password';
  @State saveToHistory: boolean = true;

  aboutToAppear(): void {
    const draft = ConnectionStore.currentDraft;
    if (draft) {
      this.host = draft.host || '';
      this.port = draft.port || '22';
      this.username = draft.username || '';
      this.password = draft.password || '';
    }
  }

  private async onConnect(): Promise<void> {
    const host = (this.host || '').trim();
    const username = (this.username || '').trim();
    const portValue = (this.port || '22').trim();

    if (!host || !username) {
      Logger.log('UI: missing host or username for connection attempt');
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'missing host or username');
      promptAction.showToast({ message: '请填写主机与用户信息' });
      return;
    }

    const auth: AuthType = this.authType === 'key' ? 'key' : 'password';
    let keyContent: string | undefined = undefined;
    let keyPublic: string | undefined = undefined;
    let keyPassphrase: string | undefined = undefined;
    if (auth === 'key') {
      const k: ImportedKey | null = KeyStore.getById(this.selectedKeyId);
      if (!k) {
        Logger.log('UI: no key selected for key-based authentication');
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'no key selected for key auth');
        promptAction.showToast({ message: '请选择已导入的密钥' });
        return;
      }
      keyContent = k.content;
      keyPublic = k.publicKey;
      keyPassphrase = k.passphrase;
    }

    const draft: ConnectionDraft = {
      host,
      port: portValue,
      username,
      password: auth === 'password' && SettingsStore.savePassword ? this.password : undefined,
      privateKey: keyContent,
      publicKey: keyPublic,
      passphrase: keyPassphrase,
    };
    if (this.saveToHistory) {
      ConnectionStore.addFromDraft(draft, auth);
    }
    ConnectionStore.currentDraft = draft;

    Logger.log(`UI: attempt ${auth} connection ${username}@${host}:${portValue}`);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'attempt connection %{public}s@%{public}s:%{public}s via %{public}s', username, host, portValue, auth);

    const parsedPort = parseInt(portValue || '22');
    const ok = auth === 'password'
      ? await SSHEngine.connectPassword(host, parsedPort, username, this.password)
      : await SSHEngine.connectKey2(host, parsedPort, username, keyContent as string, keyPublic || '', keyPassphrase);

    Logger.log(`UI: connection result ${username}@${host}:${portValue} => ${ok ? 'success' : 'failure'}`);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'connection result %{public}s@%{public}s:%{public}s => %{public}s', username, host, portValue, ok ? 'success' : 'failure');

    promptAction.showToast({ message: ok ? '连接成功' : '连接失败' });
    if (ok) {
      router.pushUrl({ url: 'pages/Terminal' });
    }
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('连接信息')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 8, bottom: 4 })

        // 认证方式切换（单选）
        Row() {
          Row() {
            Radio({ value: 'password', group: 'auth' })
              .checked(this.authType === 'password')
              .onChange((checked: boolean): void => { if (checked) { this.authType = 'password' } })
            Text('密码登录').margin({ left: 6 })
          }
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#0F000000')
          .borderRadius(12)
          Blank().width(12)
          Row() {
            Radio({ value: 'key', group: 'auth' })
              .checked(this.authType === 'key')
              .onChange((checked: boolean): void => { if (checked) { this.authType = 'key' } })
            Text('密钥登录').margin({ left: 6 })
          }
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#0F000000')
          .borderRadius(12)
        }

        TextInput({ placeholder: '主机/IP', text: this.host })
          .onChange((v: string): void => { this.host = v })

        TextInput({ placeholder: '端口(默认22)', text: this.port })
          .type(InputType.Number)
          .onChange((v: string): void => { this.port = v })

        TextInput({ placeholder: '用户名', text: this.username })
          .onChange((v: string): void => { this.username = v })

        if (this.authType === 'password') {
          TextInput({ placeholder: '密码', text: this.password })
            .type(InputType.Password)
            .onChange((v: string): void => { this.password = v })
        } else {
          Text('选择密钥')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 8 })
          if (KeyStore.list().length === 0) {
            Text('暂无已导入的密钥，请前往设置导入')
              .fontSize(12)
              .fontColor(Color.Grey)
          } else {
            Column({ space: 8 }) {
              ForEach(KeyStore.list(), (k: ImportedKey) => {
                Row() {
                  Radio({ value: k.id.toString(), group: 'keys' })
                    .checked(this.selectedKeyId === k.id)
                    .onChange((checked: boolean): void => { if (checked) { this.selectedKeyId = k.id } })
                  Text(k.name).margin({ left: 6 })
                }
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .backgroundColor(this.selectedKeyId === k.id ? '#17000000' : '#0A000000')
                .borderRadius(10)
              }, (k: ImportedKey) => k.id.toString())
            }
          }
        }

        Row() {
          Text('保存到历史')
          Blank().layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.saveToHistory })
            .onChange((v: boolean): void => { this.saveToHistory = v })
        }

        Button('连接')
          .type(ButtonType.Normal)
          .height(44)
          .backgroundColor('#222222')
          .fontColor(Color.White)
          .borderRadius(12)
          .onClick(() => { this.onConnect(); })
          .margin({ top: 8 })
      }
      .padding(16)
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}
