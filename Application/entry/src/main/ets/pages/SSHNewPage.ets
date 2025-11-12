import { promptAction, router } from '@kit.ArkUI';
import hilog from '@ohos.hilog';
import { taskpool } from '@kit.ArkTS';
import { Logger, SettingsStore, ConnectionStore, KeyStore, ImportedKey, AuthType, ConnectionDraft } from '../common/Stores';
import { SSHEngine } from '../common/SSHEngine';
import kessh from 'libkessh.so';  // 直接导入 Native 模块

const LOG_DOMAIN = 0xD15A;
const LOG_TAG = 'SSHNewPage';

/**
 * 后台线程执行 SSH 连接的任务函数
 * @concurrent 标记表示该函数可以在 taskpool 中执行
 */
@Concurrent
function sshConnectTask(host: string, port: number, username: string, password: string): number {
  'use sendable';
  // 直接调用 Native 模块，避免访问 SSHEngine 类
  return kessh.openSession(host, port, username, password);
}

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
    hilog.info(LOG_DOMAIN, LOG_TAG, '========================================');
    hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 1] 开始连接尝试');
    hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 2] 连接参数: %{public}s@%{public}s:%{public}s', username, host, portValue);
    hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 3] 认证方式: %{public}s', auth);

    const parsedPort = parseInt(portValue || '22');
    hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 4] 解析端口: %{public}d', parsedPort);
    
    // 显示连接中提示
    promptAction.showToast({ message: '正在连接...' });
    
    let ok: boolean = false;
    
    try {
      if (auth === 'password') {
        hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 5] 密码认证模式，准备在后台线程调用 SSHEngine.openSession');
        hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 6] 调用参数检查 - host: %{public}s, port: %{public}d, user: %{public}s, passLen: %{public}d',
          host, parsedPort, username, this.password.length);
        
        // 使用 taskpool 在后台线程执行网络操作
        const task = new taskpool.Task(sshConnectTask, host, parsedPort, username, this.password);
        hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 6.1] 创建 taskpool 任务，准备执行');
        
        const sessionId = await taskpool.execute(task) as number;
        
        hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 7] SSHEngine.openSession 返回 sessionId: %{public}d', sessionId);
        ok = sessionId > 0;
        hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 8] 连接结果判断: %{public}s', ok ? 'SUCCESS' : 'FAILED');
        
        if (ok) {
          hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 9] 连接成功，关闭测试会话');
          SSHEngine.closeSession(sessionId);
          hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 10] 测试会话已关闭');
        } else {
          hilog.error(LOG_DOMAIN, LOG_TAG, '[UI STEP 9 ERROR] 连接失败，sessionId <= 0');
        }
      } else {
        hilog.warn(LOG_DOMAIN, LOG_TAG, '[UI STEP 5] 密钥认证模式暂不支持');
        // FIXME: Private key authentication is not yet supported
        // const sessionId = SSHEngine.openSession(host, parsedPort, username, keyContent as string, keyPublic || '', keyPassphrase);
        // ok = sessionId > 0;
        // if (ok) SSHEngine.closeSession(sessionId);
      }
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, '[UI EXCEPTION] SSH 连接异常捕获');
      hilog.error(LOG_DOMAIN, LOG_TAG, '[UI EXCEPTION] 错误类型: %{public}s', error instanceof Error ? error.constructor.name : typeof error);
      hilog.error(LOG_DOMAIN, LOG_TAG, '[UI EXCEPTION] 错误信息: %{public}s', String(error));
      if (error instanceof Error && error.stack) {
        hilog.error(LOG_DOMAIN, LOG_TAG, '[UI EXCEPTION] 堆栈: %{public}s', error.stack);
      }
      ok = false;
    }

    Logger.log(`UI: connection result ${username}@${host}:${portValue} => ${ok ? 'success' : 'failure'}`);
    hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 11] 最终连接结果: %{public}s@%{public}s:%{public}s => %{public}s', 
      username, host, portValue, ok ? 'SUCCESS' : 'FAILURE');
    hilog.info(LOG_DOMAIN, LOG_TAG, '========================================');

    promptAction.showToast({ message: ok ? '连接成功' : '连接失败' });
    if (ok) {
      hilog.info(LOG_DOMAIN, LOG_TAG, '[UI STEP 12] 准备跳转到 Terminal 页面');
      router.pushUrl({ url: 'pages/Terminal' });
    } else {
      hilog.error(LOG_DOMAIN, LOG_TAG, '[UI STEP 12] 连接失败，不跳转页面');
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
