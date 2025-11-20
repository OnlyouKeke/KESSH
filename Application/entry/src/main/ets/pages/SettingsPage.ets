import { SettingsStore, ConnectionStore } from '../common/Stores';
import { AccountManager, HuaweiAccount } from '../common/AccountManager';
import { GuideManager } from '../common/GuideManager';
import { router, promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';

@Entry
@Component
export struct SettingsPage {
  @State isLoggedIn: boolean = false;
  @State accountInfo: HuaweiAccount | null = null;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    // 检查登录状态
    this.accountInfo = AccountManager.getCurrentAccount();
    this.isLoggedIn = AccountManager.isLoggedIn();
  }

  async handleLogin(): Promise<void> {
    try {
      const account = await AccountManager.login(this.context);
      this.accountInfo = account;
      this.isLoggedIn = true;
      promptAction.showToast({ message: `欢迎, ${account.displayName}` });
    } catch (err) {
      const error = err as Error;
      promptAction.showToast({ message: `登录失败: ${error.message}` });
      hilog.error(0xD15A, 'SettingsPage', 'Login failed: %{public}s', error.message);
    }
  }

  async handleLogout(): Promise<void> {
    try {
      await AccountManager.logout();
      this.accountInfo = null;
      this.isLoggedIn = false;
      promptAction.showToast({ message: '已登出' });
    } catch (err) {
      const error = err as Error;
      promptAction.showToast({ message: `登出失败: ${error.message}` });
    }
  }

  async handleExportConfig(): Promise<void> {
    try {
      // 导出JSON配置
      const jsonContent = ConnectionStore.exportConfig();
      
      // 使用文件选择器保存
      const documentPicker = new picker.DocumentViewPicker();
      const account = AccountManager.getCurrentAccount();
      const fileName = `kessh_config_${account?.displayName || 'user'}_${new Date().getTime()}.json`;
      
      const saveResult = await documentPicker.save({
        newFileNames: [fileName]
      });
      
      if (saveResult && saveResult.length > 0) {
        const saveUri = saveResult[0];
        
        // 将JSON内容写入文件
        const file = fileIo.openSync(saveUri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE);
        const buffer = new ArrayBuffer(jsonContent.length);
        const uint8Array = new Uint8Array(buffer);
        for (let i = 0; i < jsonContent.length; i++) {
          uint8Array[i] = jsonContent.charCodeAt(i);
        }
        fileIo.writeSync(file.fd, buffer);
        fileIo.closeSync(file);
        
        promptAction.showToast({ message: `导出成功: ${fileName}` });
        hilog.info(0xD15A, 'SettingsPage', '配置已导出到: %{public}s', saveUri);
      }
    } catch (err) {
      const error = err as Error;
      promptAction.showToast({ message: `导出失败: ${error.message}` });
      hilog.error(0xD15A, 'SettingsPage', '导出失败: %{public}s', error.message);
    }
  }

  async handleImportConfig(): Promise<void> {
    try {
      // 选择文件
      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.select({
        maxSelectNumber: 1
      });
      
      if (result && result.length > 0) {
        const uri = result[0];
        
        // 读取文件内容
        const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
        const stat = fileIo.statSync(uri);
        const buffer = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buffer);
        fileIo.closeSync(file);
        
        // 转换为JSON字符串
        const uint8Array = new Uint8Array(buffer);
        let jsonContent = '';
        for (let i = 0; i < uint8Array.length; i++) {
          jsonContent += String.fromCharCode(uint8Array[i]);
        }
        
        // 导入配置
        const importResult = await ConnectionStore.importConfig(jsonContent);
        
        promptAction.showToast({ 
          message: `导入完成: 成功${importResult.success}条, 失败${importResult.failed}条` 
        });
        
        hilog.info(0xD15A, 'SettingsPage', '导入结果: %{public}s', JSON.stringify(importResult));
      }
    } catch (err) {
      const error = err as Error;
      promptAction.showToast({ message: `导入失败: ${error.message}` });
      hilog.error(0xD15A, 'SettingsPage', '导入失败: %{public}s', error.message);
    }
  }
  
  async handleRestartGuide(): Promise<void> {
    try {
      await GuideManager.reset();
      promptAction.showToast({ message: '已重置新手引导，请重启应用' });
    } catch (err) {
      const error = err as Error;
      promptAction.showToast({ message: `重置失败: ${error.message}` });
    }
  }
  build() {
    Column() {
      List() {
        // 华为账号区域 - 已屏蔽
        // if (!this.isLoggedIn) {
        //   ListItem() {
        //     Row() {
        //       Text('华为账号登录')
        //         .fontSize(16)
        //         .fontColor($r('sys.color.ohos_id_color_emphasize'))
        //       Blank().layoutWeight(1)
        //       Text('\ue61d')
        //         .fontFamily('HarmonyOS-Sans')
        //         .fontSize(16)
        //         .fontColor($r('sys.color.ohos_id_color_fourth'))
        //     }
        //     .width('100%')
        //     .height(64)
        //     .padding({ left: 16, right: 16 })
        //   }
        //   .onClick(() => { this.handleLogin(); })
        // } else {
        //   ListItem() {
        //     Row() {
        //       // 头像区域
        //       Row() {
        //         Text(this.accountInfo?.displayName?.substring(0, 1) || 'U')
        //           .fontSize(20)
        //           .fontColor(Color.White)
        //           .fontWeight(FontWeight.Bold)
        //       }
        //       .width(48)
        //       .height(48)
        //       .borderRadius(24)
        //       .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
        //       .justifyContent(FlexAlign.Center)
        //
        //       Column({ space: 4 }) {
        //         Text(this.accountInfo?.displayName || '华为用户')
        //           .fontSize(16)
        //           .fontWeight(FontWeight.Medium)
        //         Text('已登录')
        //           .fontSize(14)
        //           .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        //       }
        //       .alignItems(HorizontalAlign.Start)
        //       .margin({ left: 12 })
        //       .layoutWeight(1)
        //
        //       Button('登出')
        //         .type(ButtonType.Normal)
        //         .height(32)
        //         .fontSize(14)
        //         .fontWeight(FontWeight.Medium)
        //         .backgroundColor($r('sys.color.ohos_id_color_warning'))
        //         .fontColor(Color.White)
        //         .borderRadius(16)
        //         .onClick(() => { this.handleLogout(); })
        //     }
        //     .width('100%')
        //     .height(80)
        //     .padding({ left: 16, right: 16 })
        //   }
        // }
        //
        // // 分隔线
        // ListItem() {
        //   Divider()
        //     .strokeWidth(8)
        //     .color($r('sys.color.ohos_id_color_list_separator'))
        // }
        // .height(8)
        //
        // // 数据管理（仅登录用户可见）
        // if (this.isLoggedIn) {
        //   ListItem() {
        //     Row() {
        //       Text('导出配置')
        //         .fontSize(16)
        //       Blank().layoutWeight(1)
        //       Text('\ue61d')
        //         .fontFamily('HarmonyOS-Sans')
        //         .fontSize(16)
        //         .fontColor($r('sys.color.ohos_id_color_fourth'))
        //     }
        //     .width('100%')
        //     .height(56)
        //     .padding({ left: 16, right: 16 })
        //   }
        //   .onClick(() => { this.handleExportConfig(); })
        //
        //   ListItem() {
        //     Row() {
        //       Text('导入配置')
        //         .fontSize(16)
        //       Blank().layoutWeight(1)
        //       Text('\ue61d')
        //         .fontFamily('HarmonyOS-Sans')
        //         .fontSize(16)
        //         .fontColor($r('sys.color.ohos_id_color_fourth'))
        //     }
        //     .width('100%')
        //     .height(56)
        //     .padding({ left: 16, right: 16 })
        //   }
        //   .onClick(() => { this.handleImportConfig(); })
        // }
        //
        // // 分隔线
        // ListItem() {
        //   Divider()
        //     .strokeWidth(8)
        //     .color($r('sys.color.ohos_id_color_list_separator'))
        // }
        // .height(8)

        // 子页面入口
        ListItem() {
          Row() {
            Text('密钥管理')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('\ue61d')
              .fontFamily('HarmonyOS-Sans')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_fourth'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => { 
          router.pushUrl({ url: 'pages/SettingsKeys' }, (err) => {
            if (err) {
              hilog.error(0xD15A, 'SettingsPage', 'Navigate to SettingsKeys failed: %{public}s', err.message);
            }
          });
        })

        ListItem() {
          Row() {
            Text('会话设置')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('\ue61d')
              .fontFamily('HarmonyOS-Sans')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_fourth'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => {
          router.pushUrl({ url: 'pages/SettingsSession' });
        })

        ListItem() {
          Row() {
            Text('终端字体')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('\ue61d')
              .fontFamily('HarmonyOS-Sans')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_fourth'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => {
          router.pushUrl({ url: 'pages/SettingsTerminalFont' });
        })
        
        ListItem() {
          Row() {
            Text('隐私协议')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('\ue61d')
              .fontFamily('HarmonyOS-Sans')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_fourth'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => { 
          router.pushUrl({ url: 'pages/PrivacyPolicy' });
        })
        
        ListItem() {
          Row() {
            Text('用户协议')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('\ue61d')
              .fontFamily('HarmonyOS-Sans')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_fourth'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => { 
          router.pushUrl({ url: 'pages/UserAgreement' });
        })
        
        ListItem() {
          Row() {
            Text('问题反馈')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('\ue61d')
              .fontFamily('HarmonyOS-Sans')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_fourth'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        .onClick((): void => { 
          router.pushUrl({ url: 'pages/Feedback' });
        })
        
        // 重新开始引导 - 已屏蔽
        // ListItem() {
        //   Row() {
        //     Text('重新开始引导')
        //       .fontSize(16)
        //     Blank().layoutWeight(1)
        //     Text('\ue61d')
        //       .fontFamily('HarmonyOS-Sans')
        //       .fontSize(16)
        //       .fontColor($r('sys.color.ohos_id_color_fourth'))
        //   }
        //   .width('100%')
        //   .height(56)
        //   .padding({ left: 16, right: 16 })
        // }
        // .onClick((): void => { 
        //   this.handleRestartGuide();
        // })
        
        ListItem() {
          Row() {
            Text('当前版本')
              .fontSize(16)
            Blank().layoutWeight(1)
            Text('1.3.0')
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
        }
        
        // 账号功能说明 - 已屏蔽
        // if (this.isLoggedIn) {
        //   ListItem() {
        //     Column({ space: 8 }) {
        //       Text('🔐 数据安全')
        //         .fontSize(14)
        //         .fontWeight(FontWeight.Medium)
        //         .width('100%')
        //       Text('您的SSH密码已使用账号ID加密存储在本地，不同账号数据完全隔离。导出的配置文件仅包含加密后的密码，只有同一账号才能解密。')
        //         .fontSize(12)
        //         .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        //         .width('100%')
        //       Text('⚠️ 导出的配置文件包含加密密码，请妥善保管。切换账号后导入旧账号的配置文件，密码将无法解密。')
        //         .fontSize(12)
        //         .fontColor($r('sys.color.ohos_id_color_warning'))
        //         .width('100%')
        //     }
        //     .width('100%')
        //     .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        //   }
        // }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
