import { Switch } from '@lynx-js/lynx-ui';
import { useEffect, useState } from '@lynx-js/react';

import { Card, PageHeader } from '../components/Page';
import { useNavigator } from '../navigation/Navigator';
import type { RouteName } from '../navigation/Navigator';
import { KesshHost } from '../native/host';
import type { AppSettings } from '../native/host';

const SUB_PAGES: { key: RouteName; title: string; subtitle: string }[] = [
  { key: 'SettingsKeys', title: '密钥管理', subtitle: '导入和管理 SSH 私钥/公钥' },
  { key: 'SettingsSession', title: '会话设置', subtitle: 'SSH keepalive 间隔与重试' },
  { key: 'SettingsTerminalFont', title: '终端字体', subtitle: '字体族、大小与预览' },
  { key: 'Tools', title: '工具', subtitle: 'Ping / 端口测试 / Base64 / 子网' },
  { key: 'WebSocketTest', title: 'WebSocket 测试', subtitle: '调试本地 WebSocket 代理' },
  { key: 'WebSocketSSHTest', title: 'WebSocket SSH', subtitle: '通过代理建立 SSH 隧道' },
  { key: 'SettingsLogs', title: '日志', subtitle: '查看应用运行日志' },
  { key: 'PrivacyPolicy', title: '隐私政策', subtitle: '了解我们如何处理您的数据' },
  { key: 'UserAgreement', title: '用户协议', subtitle: '使用本应用须知' },
  { key: 'Feedback', title: '问题反馈', subtitle: '反馈问题或建议' }
];

export function SettingsPage() {
  const navigator = useNavigator();
  const [settings, setSettings] = useState<AppSettings | null>(null);

  useEffect(() => {
    KesshHost.getSettings()
      .then((value) => setSettings(value))
      .catch(() => {
        setSettings({
          darkMode: false,
          savePassword: false,
          session: { keepaliveInterval: 60, keepaliveAttempts: 3, terminalFontFamily: 'system', terminalFontSize: 14 }
        });
      });
  }, []);

  if (!settings) {
    return (
      <view className="page">
        <PageHeader title="设置" />
      </view>
    );
  }

  return (
    <view className="page">
      <PageHeader title="设置" />

      <scroll-view scroll-y style={{ flex: 1, padding: 16 }}>
        <Card>
          <view className="card-row">
            <view style={{ flex: 1 }}>
              <text className="card-title">深色模式</text>
              <text className="card-subtitle">跟随系统或手动切换</text>
            </view>
            <Switch
              checked={settings.darkMode}
              onChange={(checked) => {
                setSettings({ ...settings, darkMode: checked });
                KesshHost.setDarkMode(checked).catch(() => undefined);
              }}
            />
          </view>
        </Card>

        <Card>
          <view className="card-row">
            <view style={{ flex: 1 }}>
              <text className="card-title">保存密码</text>
              <text className="card-subtitle">使用本地安全存储</text>
            </view>
            <Switch
              checked={settings.savePassword}
              onChange={(checked) => {
                setSettings({ ...settings, savePassword: checked });
                KesshHost.setSavePassword(checked).catch(() => undefined);
              }}
            />
          </view>
        </Card>

        {SUB_PAGES.map((entry) => (
          <Card key={entry.key} onTap={() => navigator.push(entry.key)}>
            <view className="card-row">
              <view style={{ flex: 1 }}>
                <text className="card-title">{entry.title}</text>
                <text className="card-subtitle">{entry.subtitle}</text>
              </view>
              <text className="card-subtitle">{'>'}</text>
            </view>
          </Card>
        ))}
      </scroll-view>
    </view>
  );
}
