import { promptAction, router } from '@kit.ArkUI';
import hilog from '@ohos.hilog';
import { taskpool } from '@kit.ArkTS';
import { Logger, SettingsStore, ConnectionStore, KeyStore, ImportedKey, AuthType, ConnectionDraft, ConnectionStatus } from '../common/Stores';
import { SSHEngine } from '../common/SSHEngine';
import kessh from 'libkessh.so';

const LOG_DOMAIN = 0xD15A;
const LOG_TAG = 'SSHNewPage';

/**
 * 后台线程执行 SSH 连接的任务函数
 */
@Concurrent
function sshConnectTask(host: string, port: number, username: string, password: string): number {
  return kessh.openSession(host, port, username, password);
}

@Entry
@Component
export struct SSHNewPage {
  @State host: string = '';
  @State port: string = '22';
  @State username: string = '';
  @State password: string = '';
  @State selectedKeyId: number = -1;
  @State authType: string = 'password';
  @State saveToHistory: boolean = true;
  @State savePassword: boolean = false;
  @State isEditMode: boolean = false;
  @State editingId: number = -1;

  aboutToAppear(): void {
    const draft = ConnectionStore.currentDraft;
    if (draft) {
      this.host = draft.host || '';
      this.port = draft.port || '22';
      this.username = draft.username || '';
      this.password = draft.password || '';
      // 如果从历史记录带来了密码，自动勾选保存密码
      if (draft.password) {
        this.savePassword = true;
      }
      // 检查是否为编辑模式
      if (draft.isEditing && draft.editingId) {
        this.isEditMode = true;
        this.editingId = draft.editingId;
      }
    }
  }

  private async onSave(): Promise<void> {
    const host = (this.host || '').trim();
    const username = (this.username || '').trim();
    const portValue = (this.port || '22').trim();

    if (!host || !username) {
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
      password: auth === 'password' && this.savePassword ? this.password : undefined,
      privateKey: keyContent,
      publicKey: keyPublic,
      passphrase: keyPassphrase,
    };
    
    // 直接保存到历史
    if (this.saveToHistory) {
      try {
        if (this.isEditMode && this.editingId > 0) {
          // 编辑模式：先删除旧记录，再添加新记录
          ConnectionStore.remove(this.editingId);
          ConnectionStore.addFromDraft(draft, auth, undefined, undefined, undefined, this.savePassword);
          promptAction.showToast({ message: '更新成功' });
        } else {
          // 新建模式
          ConnectionStore.addFromDraft(draft, auth, undefined, undefined, undefined, this.savePassword);
          promptAction.showToast({ message: '保存成功' });
        }
        // 跳转到首页而不是返回
        router.replaceUrl({ url: 'pages/Index' });
      } catch (err) {
        const error = err as Error;
        promptAction.showToast({ message: `保存失败: ${error.message}` });
        Logger.error(`保存主机失败: ${error.message}`);
      }
    }
  }
  
  private async onConnect(): Promise<void> {
    const host = (this.host || '').trim();
    const username = (this.username || '').trim();
    const portValue = (this.port || '22').trim();

    if (!host || !username) {
      promptAction.showToast({ message: '请填写主机与用户信息' });
      return;
    }
    
    if (this.authType === 'password' && !this.password) {
      promptAction.showToast({ message: '请输入密码' });
      return;
    }

    const auth: AuthType = this.authType === 'key' ? 'key' : 'password';
    let keyContent: string | undefined = undefined;
    let keyPublic: string | undefined = undefined;
    let keyPassphrase: string | undefined = undefined;
    
    if (auth === 'key') {
      const k: ImportedKey | null = KeyStore.getById(this.selectedKeyId);
      if (!k) {
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
      password: auth === 'password' ? this.password : undefined,
      privateKey: keyContent,
      publicKey: keyPublic,
      passphrase: keyPassphrase,
    };
    
    // 保存到历史
    if (this.saveToHistory) {
      ConnectionStore.addFromDraft(draft, auth, undefined, undefined, undefined, this.savePassword);
    }
    
    // 设置当前draft供Terminal使用
    ConnectionStore.currentDraft = draft;
    
    // 跳转到Terminal
    router.pushUrl({ url: 'pages/Terminal' });
  }

  build() {
    Column() {
      // 主体内容
      Scroll() {
        Column({ space: 12 }) {
          // 认证方式切换(单选)
          Row() {
            Row() {
              Radio({ value: 'password', group: 'auth' })
                .checked(this.authType === 'password')
                .onChange((checked: boolean): void => { if (checked) { this.authType = 'password' } })
              Text('密码登录').margin({ left: 6 })
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .borderRadius(8)
            
            Blank().width(12)
            
            Row() {
              Radio({ value: 'key', group: 'auth' })
                .checked(this.authType === 'key')
                .onChange((checked: boolean): void => { if (checked) { this.authType = 'key' } })
              Text('密钥登录').margin({ left: 6 })
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .borderRadius(8)
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
          
          Row() {
            Text('保存密码')
            Blank().layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.savePassword })
              .onChange((v: boolean): void => { this.savePassword = v })
          }
        } else {
          Text('选择密钥')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 8 })
          if (KeyStore.list().length === 0) {
            Text('暂无已导入的密钥，请前往设置导入')
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
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
                .backgroundColor(this.selectedKeyId === k.id ? $r('sys.color.ohos_id_color_emphasize') : $r('sys.color.ohos_id_color_button_normal'))
                .borderRadius(8)
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

        Row({ space: 12 }) {
          Button(this.isEditMode ? '更新' : '保存')
            .type(ButtonType.Capsule)
            .layoutWeight(1)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('app.color.login_button'))
            .fontColor(Color.White)
            .borderRadius(24)
            .onClick(() => { this.onSave(); })

          Button('连接')
            .type(ButtonType.Capsule)
            .layoutWeight(1)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
            .fontColor(Color.White)
            .borderRadius(24)
            .onClick(() => { this.onConnect(); })
        }
        .margin({ top: 16 })
      }
      .padding(16)
      .width('100%')
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .width('100%')
  }
    .width('100%')
    .height('100%')
  }
}
