import { Input } from '@lynx-js/lynx-ui';
import { useEffect, useState } from '@lynx-js/react';

import { Card, EmptyState, PageHeader, PrimaryAction } from '../components/Page';
import { useFontOptions } from '../native/hooks';
import { KesshHost } from '../native/host';

export function SettingsTerminalFontPage() {
  const { data: options, loading } = useFontOptions();
  const [selected, setSelected] = useState<string>('system');
  const [size, setSize] = useState<string>('14');
  const [saving, setSaving] = useState<boolean>(false);

  useEffect(() => {
    KesshHost.getSettings()
      .then((settings) => {
        setSelected(settings.session.terminalFontFamily);
        setSize(settings.session.terminalFontSize.toString());
      })
      .catch(() => undefined);
  }, []);

  async function selectFont(key: string) {
    if (selected === key) return;
    setSelected(key);
    try {
      await KesshHost.setSessionSettings({ terminalFontFamily: key });
      await KesshHost.showToast('字体已更新').catch(() => undefined);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await KesshHost.showToast(`更新失败: ${message}`).catch(() => undefined);
    }
  }

  async function saveSize() {
    if (saving) return;
    setSaving(true);
    try {
      const parsed = parseInt(size, 10);
      const clamped = Number.isNaN(parsed) ? 14 : Math.max(8, Math.min(48, parsed));
      await KesshHost.setSessionSettings({ terminalFontSize: clamped });
      await KesshHost.showToast('字体大小已保存').catch(() => undefined);
    } finally {
      setSaving(false);
    }
  }

  const previewFamily = options?.find((option) => option.key === selected)?.family ?? 'monospace';

  return (
    <view className="page">
      <PageHeader title="终端字体" />

      <view style={{ padding: 16, gap: 16 }}>
        <Card>
          <text className="card-title">当前字体预览</text>
          <view style={{ marginTop: 8 }}>
            <text style={{ fontFamily: previewFamily, fontSize: parseInt(size, 10) || 14 }}>0O iIl1 ~-= {'<>'} {'{}'} () 0123456789</text>
            <text style={{ fontFamily: previewFamily, fontSize: parseInt(size, 10) || 14 }}>ssh root@192.168.1.100 -p 22</text>
            <text style={{ fontFamily: previewFamily, fontSize: parseInt(size, 10) || 14 }}>export PATH=$PATH:/usr/local/bin</text>
          </view>
        </Card>

        <text className="section-title" style={{ padding: 0 }}>字体列表</text>
        {loading ? (
          <EmptyState title="加载中..." />
        ) : (options ?? []).length === 0 ? (
          <EmptyState title="未找到字体选项" />
        ) : (
          (options ?? []).map((option) => (
            <Card key={option.key} onTap={() => selectFont(option.key)}>
              <view className="card-row">
                <view style={{ flex: 1 }}>
                  <text className="card-title">{option.label}</text>
                  <text className="card-subtitle">{option.description}</text>
                  <text style={{ fontFamily: option.family, fontSize: 13, marginTop: 4 }}>
                    0O iIl1 ~-= {'{}'} () 123456
                  </text>
                </view>
                {selected === option.key ? (
                  <text style={{ color: 'var(--primary)', fontSize: 18 }}>✓</text>
                ) : null}
              </view>
            </Card>
          ))
        )}

        <view className="form-field">
          <text className="form-field-label">字体大小</text>
          <Input
            className="form-field-input"
            value={size}
            type="number"
            placeholder="例如 14"
            onInput={(value) => setSize(value)}
          />
        </view>
        <PrimaryAction label={saving ? '保存中…' : '保存大小'} onTap={saveSize} disabled={saving} />
      </view>
    </view>
  );
}
