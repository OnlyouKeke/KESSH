import { authentication } from '@kit.AccountKit';
import preferences from '@ohos.data.preferences';
import type { Context } from '@kit.AbilityKit';
import { Logger } from './Stores';

/**
 * 华为账号信息
 */
export interface HuaweiAccount {
  openId: string;           // 华为账号唯一ID
  displayName: string;      // 昵称
  avatarUri?: string;       // 头像URI
  unionId?: string;         // UnionID
}

/**
 * 账号管理器
 */
export class AccountManager {
  private static currentAccount: HuaweiAccount | null = null;
  private static prefStore: preferences.Preferences | null = null;
  private static readonly PREF_NAME = 'kessh_account';
  private static readonly KEY_ACCOUNT = 'current_account';

  /**
   * 初始化账号管理器
   */
  static async init(context: Context): Promise<void> {
    try {
      AccountManager.prefStore = await preferences.getPreferences(context, AccountManager.PREF_NAME);
      
      // 读取已保存的账号信息
      const accountJson = await AccountManager.prefStore.get(AccountManager.KEY_ACCOUNT, '');
      if (accountJson && accountJson !== '') {
        AccountManager.currentAccount = JSON.parse(accountJson as string);
        Logger.info(`AccountManager: 加载已登录账号 ${AccountManager.currentAccount?.displayName}`);
      } else {
        Logger.info('AccountManager: 未登录');
      }
    } catch (err) {
      Logger.error(`AccountManager: 初始化失败 ${err}`);
    }
  }

  /**
   * 华为账号登录
   */
  static async login(context: Context): Promise<HuaweiAccount> {
    try {
      Logger.info('AccountManager: 开始华为账号登录...');
      
      // 创建认证请求
      const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
      
      // 设置请求的授权范围
      authRequest.scopes = ['openid', 'profile'];
      authRequest.state = Math.random().toString(36).slice(2);
      
      // 执行认证
      const controller = new authentication.AuthenticationController(context);
      const authResponse = await controller.executeRequest(authRequest);
      
      if (!authResponse) {
        throw new Error('登录失败：未获取到授权数据');
      }

      // 获取用户信息
      const responseData: Record<string, Object> = authResponse as Record<string, Object>;
      
      // 华为账号返回的数据结构：{ data: { openID, unionID, nickName, ... }, state: ... }
      const data = responseData['data'] as Record<string, Object>;
      
      if (!data) {
        Logger.error(`AccountManager: 响应数据: ${JSON.stringify(responseData)}`);
        throw new Error('登录失败：响应数据格式错误');
      }
      
      // 检查是否有用户信息（注意字段名：openID, unionID, nickName）
      const openId = data['openID'] as string;
      const displayName = data['nickName'] as string;
      const unionId = data['unionID'] as string;
      
      if (!openId) {
        Logger.error(`AccountManager: 用户数据: ${JSON.stringify(data)}`);
        throw new Error('登录失败：未获取到用户ID');
      }
      
      const account: HuaweiAccount = {
        openId: openId,
        displayName: displayName || '华为用户',
        avatarUri: data['avatarUri'] as string,
        unionId: unionId
      };

      // 保存账号信息
      AccountManager.currentAccount = account;
      await AccountManager.saveAccount();

      Logger.info(`AccountManager: 登录成功 ${account.displayName} (${account.openId})`);
      return account;
    } catch (err) {
      const error = err as Error;
      Logger.error(`AccountManager: 登录失败 ${error.message}`);
      throw new Error(`登录失败: ${error.message}`);
    }
  }

  /**
   * 静默登录（刷新token）
   */
  static async silentLogin(context: Context): Promise<HuaweiAccount | null> {
    try {
      if (!AccountManager.currentAccount) {
        return null;
      }

      Logger.info('AccountManager: 尝试静默登录...');
      
      // 创建静默登录请求
      const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
      authRequest.scopes = ['openid', 'profile'];

      const controller = new authentication.AuthenticationController(context);
      const authResponse = await controller.executeRequest(authRequest);
      
      if (authResponse) {
        const responseData: Record<string, Object> = authResponse as Record<string, Object>;
        const data = responseData['data'] as Record<string, Object>;
        
        if (data) {
          const account: HuaweiAccount = {
            openId: (data['openID'] as string) || AccountManager.currentAccount.openId,
            displayName: (data['nickName'] as string) || AccountManager.currentAccount.displayName,
            avatarUri: (data['avatarUri'] as string) || AccountManager.currentAccount.avatarUri,
            unionId: (data['unionID'] as string) || AccountManager.currentAccount.unionId
          };

          AccountManager.currentAccount = account;
          await AccountManager.saveAccount();
          
          Logger.info('AccountManager: 静默登录成功');
          return account;
        }
      }
      
      return AccountManager.currentAccount;
    } catch (err) {
      Logger.error(`AccountManager: 静默登录失败 ${err}`);
      return AccountManager.currentAccount;
    }
  }

  /**
   * 登出
   */
  static async logout(): Promise<void> {
    try {
      Logger.info('AccountManager: 开始登出...');
      
      // 清除账号信息
      AccountManager.currentAccount = null;
      
      if (AccountManager.prefStore) {
        await AccountManager.prefStore.delete(AccountManager.KEY_ACCOUNT);
        await AccountManager.prefStore.flush();
      }

      Logger.info('AccountManager: 登出成功');
    } catch (err) {
      Logger.error(`AccountManager: 登出失败 ${err}`);
      throw new Error('登出失败');
    }
  }

  /**
   * 获取当前登录的账号
   */
  static getCurrentAccount(): HuaweiAccount | null {
    return AccountManager.currentAccount;
  }

  /**
   * 是否已登录
   */
  static isLoggedIn(): boolean {
    return AccountManager.currentAccount !== null;
  }

  /**
   * 获取用户加密密钥（基于用户ID）
   */
  static getEncryptionKey(): string {
    if (!AccountManager.currentAccount) {
      // 未登录时使用默认密钥
      return 'KESSH_2025_SECURE_KEY_V1';
    }
    
    // 使用用户openId作为加密密钥的一部分
    return `KESSH_USER_${AccountManager.currentAccount.openId}_KEY`;
  }

  /**
   * 保存账号信息
   */
  private static async saveAccount(): Promise<void> {
    if (!AccountManager.prefStore || !AccountManager.currentAccount) {
      return;
    }

    try {
      const accountJson = JSON.stringify(AccountManager.currentAccount);
      await AccountManager.prefStore.put(AccountManager.KEY_ACCOUNT, accountJson);
      await AccountManager.prefStore.flush();
      Logger.info('AccountManager: 账号信息已保存');
    } catch (err) {
      Logger.error(`AccountManager: 保存账号信息失败 ${err}`);
    }
  }
}
