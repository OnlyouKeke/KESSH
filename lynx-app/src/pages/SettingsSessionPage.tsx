import { Input } from '@lynx-js/lynx-ui';
import { useEffect, useState } from '@lynx-js/react';

import { PageHeader, PrimaryAction } from '../components/Page';
import { KesshHost } from '../native/host';

function clamp(value: number, min: number, max: number): number {
  if (Number.isNaN(value)) return min;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

export function SettingsSessionPage() {
  const [intervalText, setIntervalText] = useState<string>('60');
  const [attemptsText, setAttemptsText] = useState<string>('3');
  const [saving, setSaving] = useState<boolean>(false);

  useEffect(() => {
    KesshHost.getSettings()
      .then((settings) => {
        setIntervalText(settings.session.keepaliveInterval.toString());
        setAttemptsText(settings.session.keepaliveAttempts.toString());
      })
      .catch(() => undefined);
  }, []);

  async function save() {
    if (saving) return;
    setSaving(true);
    try {
      const interval = clamp(parseInt(intervalText, 10), 5, 3600);
      const attempts = clamp(parseInt(attemptsText, 10), 1, 10);
      await KesshHost.setSessionSettings({ keepaliveInterval: interval, keepaliveAttempts: attempts });
      await KesshHost.showToast('会话设置已保存').catch(() => undefined);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await KesshHost.showToast(`保存失败: ${message}`).catch(() => undefined);
    } finally {
      setSaving(false);
    }
  }

  return (
    <view className="page">
      <PageHeader title="会话设置" />

      <view style={{ padding: 16, gap: 16 }}>
        <view className="form-field">
          <text className="form-field-label">保活时间间隔（秒）</text>
          <Input
            className="form-field-input"
            value={intervalText}
            type="number"
            placeholder="建议 10-300"
            onInput={(value) => setIntervalText(value)}
          />
          <text className="card-subtitle" style={{ marginTop: 4 }}>每次保活会在设置的间隔内发送 SSH keepalive 请求，避免会话被服务器断开。</text>
        </view>

        <view className="form-field">
          <text className="form-field-label">失败后重试次数</text>
          <Input
            className="form-field-input"
            value={attemptsText}
            type="number"
            placeholder="建议 1-5 次"
            onInput={(value) => setAttemptsText(value)}
          />
          <text className="card-subtitle" style={{ marginTop: 4 }}>连续多次保活失败后将提示并自动断开连接。</text>
        </view>

        <PrimaryAction label={saving ? '保存中…' : '保存设置'} onTap={save} disabled={saving} />
      </view>
    </view>
  );
}
