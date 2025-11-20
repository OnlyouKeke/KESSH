import preferences from '@ohos.data.preferences';
import type { Context } from '@kit.AbilityKit';
import { Logger } from './Stores';

const PREF_NAME = 'kessh_guide';
const KEY_GUIDE_COMPLETED = 'guide_completed';

export interface GuideProgress {
  current: number;
  total: number;
}

/**
 * 新手引导步骤
 */
export interface GuideStep {
  id: string;
  title: string;
  description: string;
  targetPage?: string; // 目标页面，用于页面跳转
  highlightArea?: GuideHighlight; // 高亮区域
}

export interface GuideHighlight {
  x: number;
  y: number;
  width: number;
  height: number;
}

/**
 * 新手引导管理器
 */
export class GuideManager {
  private static prefStore: preferences.Preferences | null = null;
  private static isGuideCompleted: boolean = false;
  private static currentStepIndex: number = 0;
  
  // 新手引导步骤定义
  static readonly GUIDE_STEPS: GuideStep[] = [
    {
      id: 'welcome',
      title: '欢迎使用 KESSH',
      description: 'KESSH 是一款功能强大的 SSH 客户端，让我们开始吧！'
    },
    {
      id: 'add_host',
      title: '添加主机',
      description: '首先，点击"添加主机"标签页，配置你的第一台服务器',
      targetPage: 'add_host'
    },
    {
      id: 'fill_info',
      title: '填写连接信息',
      description: '输入服务器地址、端口、用户名和密码，然后点击"连接"按钮'
    },
    {
      id: 'terminal',
      title: '使用终端',
      description: '连接成功后，你可以在终端中执行命令，与服务器交互'
    },
    {
      id: 'tools',
      title: '实用工具',
      description: '在"工具箱"中，你可以使用 Ping、端口测试、Base64 编解码等网络工具',
      targetPage: 'tools'
    },
    {
      id: 'settings',
      title: '个性化设置',
      description: '在"设置"页面，你可以管理密钥、查看日志、导入导出配置等',
      targetPage: 'settings'
    },
    {
      id: 'complete',
      title: '引导完成',
      description: '现在你已经掌握了基本操作，开始探索更多功能吧！'
    }
  ];

  /**
   * 初始化引导管理器
   */
  static async init(context: Context): Promise<void> {
    try {
      GuideManager.prefStore = await preferences.getPreferences(context, PREF_NAME);
      
      // 读取引导完成标记
      const completed = await GuideManager.prefStore.get(KEY_GUIDE_COMPLETED, false);
      GuideManager.isGuideCompleted = completed as boolean;
      
      Logger.info(`GuideManager: 初始化完成, 引导已完成=${GuideManager.isGuideCompleted}`);
    } catch (err) {
      Logger.error(`GuideManager: 初始化失败 ${err}`);
    }
  }

  /**
   * 检查是否需要显示新手引导
   */
  static shouldShowGuide(): boolean {
    return !GuideManager.isGuideCompleted;
  }

  /**
   * 标记引导已完成
   */
  static async markCompleted(): Promise<void> {
    if (!GuideManager.prefStore) return;
    
    try {
      GuideManager.isGuideCompleted = true;
      await GuideManager.prefStore.put(KEY_GUIDE_COMPLETED, true);
      await GuideManager.prefStore.flush();
      Logger.info('GuideManager: 引导已完成');
    } catch (err) {
      Logger.error(`GuideManager: 保存引导完成标记失败 ${err}`);
    }
  }

  /**
   * 重置引导（用于测试）
   */
  static async reset(): Promise<void> {
    if (!GuideManager.prefStore) return;
    
    try {
      GuideManager.isGuideCompleted = false;
      GuideManager.currentStepIndex = 0;
      await GuideManager.prefStore.put(KEY_GUIDE_COMPLETED, false);
      await GuideManager.prefStore.flush();
      Logger.info('GuideManager: 引导已重置');
    } catch (err) {
      Logger.error(`GuideManager: 重置引导失败 ${err}`);
    }
  }

  /**
   * 获取当前步骤
   */
  static getCurrentStep(): GuideStep | null {
    if (GuideManager.currentStepIndex >= GuideManager.GUIDE_STEPS.length) {
      return null;
    }
    return GuideManager.GUIDE_STEPS[GuideManager.currentStepIndex];
  }

  /**
   * 前进到下一步
   */
  static nextStep(): GuideStep | null {
    GuideManager.currentStepIndex++;
    return GuideManager.getCurrentStep();
  }

  /**
   * 后退到上一步
   */
  static previousStep(): GuideStep | null {
    if (GuideManager.currentStepIndex > 0) {
      GuideManager.currentStepIndex--;
    }
    return GuideManager.getCurrentStep();
  }

  /**
   * 跳过引导
   */
  static async skip(): Promise<void> {
    await GuideManager.markCompleted();
  }

  /**
   * 获取引导进度
   */
  static getProgress(): GuideProgress {
    const progress: GuideProgress = {
      current: GuideManager.currentStepIndex + 1,
      total: GuideManager.GUIDE_STEPS.length
    };
    return progress;
  }
}
