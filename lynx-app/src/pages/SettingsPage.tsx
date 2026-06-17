import { Switch } from '@lynx-js/lynx-ui';
import { useEffect, useState } from '@lynx-js/react';

import { Card, PageHeader } from '../components/Page';
import { useNavigator } from '../navigation/Navigator';
import { KesshHost } from '../native/host';
import type { AppSettings } from '../native/host';

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

      <view style={{ padding: 16, gap: 12 }}>
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

        <Card onTap={() => navigator.push('SettingsKeys')}>
          <view className="card-row">
            <text className="card-title">密钥管理</text>
            <text className="card-subtitle">{'>'}</text>
          </view>
        </Card>

        <Card onTap={() => navigator.push('SettingsSession')}>
          <view className="card-row">
            <text className="card-title">会话设置</text>
            <text className="card-subtitle">{'>'}</text>
          </view>
        </Card>

        <Card onTap={() => navigator.push('SettingsTerminalFont')}>
          <view className="card-row">
            <text className="card-title">终端字体</text>
            <text className="card-subtitle">{'>'}</text>
          </view>
        </Card>

        <Card onTap={() => navigator.push('SettingsLogs')}>
          <view className="card-row">
            <text className="card-title">日志</text>
            <text className="card-subtitle">{'>'}</text>
          </view>
        </Card>
      </view>
    </view>
  );
}
