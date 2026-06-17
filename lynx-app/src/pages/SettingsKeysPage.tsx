import { Input, KeyboardAwareTrigger, TextArea } from '@lynx-js/lynx-ui';
import { useState } from '@lynx-js/react';

import { Card, EmptyState, PageHeader, PrimaryAction } from '../components/Page';
import { KeyboardAwarePage } from '../components/KeyboardAwarePage';
import { useKeys } from '../native/hooks';
import { KesshHost } from '../native/host';

export function SettingsKeysPage() {
  const { data, loading, error, reload } = useKeys();
  const [name, setName] = useState<string>('');
  const [content, setContent] = useState<string>('');
  const [publicKey, setPublicKey] = useState<string>('');
  const [passphrase, setPassphrase] = useState<string>('');

  async function importKey() {
    if (!name.trim() || !content.trim()) {
      await KesshHost.showToast('请填写名称和私钥').catch(() => undefined);
      return;
    }
    try {
      await KesshHost.importKey(name.trim(), content, publicKey, passphrase);
      setName('');
      setContent('');
      setPublicKey('');
      setPassphrase('');
      reload();
      await KesshHost.showToast('已保存').catch(() => undefined);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await KesshHost.showToast(`保存失败: ${message}`).catch(() => undefined);
    }
  }

  async function removeKey(id: number) {
    await KesshHost.removeKey(id).catch(() => undefined);
    reload();
  }

  return (
    <KeyboardAwarePage>
      <PageHeader title="密钥管理" />

      <view style={{ padding: 16, gap: 12 }}>
        <text className="section-title" style={{ padding: 0 }}>导入密钥</text>
        <KeyboardAwareTrigger>
          <view className="form-field">
            <text className="form-field-label">密钥名称</text>
            <Input className="form-field-input" value={name} onInput={(value) => setName(value)} />
          </view>
        </KeyboardAwareTrigger>
        <KeyboardAwareTrigger>
          <view className="form-field">
            <text className="form-field-label">私钥 (PEM)</text>
            <TextArea className="form-field-input" value={content} onInput={(value) => setContent(value)} />
          </view>
        </KeyboardAwareTrigger>
        <KeyboardAwareTrigger>
          <view className="form-field">
            <text className="form-field-label">公钥（可选）</text>
            <TextArea className="form-field-input" value={publicKey} onInput={(value) => setPublicKey(value)} />
          </view>
        </KeyboardAwareTrigger>
        <KeyboardAwareTrigger>
          <view className="form-field">
            <text className="form-field-label">密码短语（可选）</text>
            <Input className="form-field-input" value={passphrase} type="password" onInput={(value) => setPassphrase(value)} />
          </view>
        </KeyboardAwareTrigger>
        <PrimaryAction label="保存密钥" onTap={importKey} />
      </view>

      <text className="section-title">已导入密钥</text>
      {loading ? (
        <EmptyState title="加载中..." />
      ) : error ? (
        <EmptyState title={`数据源不可用 (${error.message})`} />
      ) : (data ?? []).length === 0 ? (
        <EmptyState title="暂无密钥" />
      ) : (
        <view style={{ padding: 16, gap: 12 }}>
          {(data ?? []).map((key) => (
            <Card key={key.id} onTap={() => removeKey(key.id)}>
              <view className="card-row">
                <view style={{ flex: 1 }}>
                  <text className="card-title">{key.name}</text>
                  {key.fingerprint ? (
                    <text className="card-subtitle">指纹: {key.fingerprint.slice(0, 32)}…</text>
                  ) : null}
                </view>
                <text className="card-subtitle">点击删除</text>
              </view>
            </Card>
          ))}
        </view>
      )}
    </KeyboardAwarePage>
  );
}
