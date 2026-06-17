import { useState } from '@lynx-js/react';
import { Input, KeyboardAwareResponder, KeyboardAwareRoot, KeyboardAwareTrigger } from '@lynx-js/lynx-ui';

import { PageHeader, PrimaryAction } from '../components/Page';
import { useNavigator } from '../navigation/Navigator';
import { KesshHost } from '../native/host';
import type { ConnectionDraft } from '../native/host';

export interface AddHostParams {
  editingId?: number;
  host?: string;
  port?: number;
  username?: string;
}

function parsePort(text: string): number | null {
  if (!/^\d+$/.test(text.trim())) return null;
  const value = parseInt(text, 10);
  if (Number.isNaN(value) || value < 1 || value > 65535) return null;
  return value;
}

export function AddHostPage({ params }: { params?: Record<string, unknown> }) {
  const navigator = useNavigator();
  const initial = (params ?? {}) as AddHostParams;

  const [host, setHost] = useState<string>(initial.host ?? '');
  const [port, setPort] = useState<string>((initial.port ?? 22).toString());
  const [username, setUsername] = useState<string>(initial.username ?? '');
  const [password, setPassword] = useState<string>('');
  const [submitting, setSubmitting] = useState<boolean>(false);

  const isEditing = typeof initial.editingId === 'number';

  async function saveAndConnect() {
    if (submitting) return;
    if (!host.trim()) {
      await KesshHost.showToast('请填写主机地址').catch(() => undefined);
      return;
    }
    if (!username.trim()) {
      await KesshHost.showToast('请填写用户名').catch(() => undefined);
      return;
    }
    const portValue = parsePort(port || '22');
    if (portValue === null) {
      await KesshHost.showToast('端口必须是 1-65535 的数字').catch(() => undefined);
      return;
    }
    if (!password) {
      await KesshHost.showToast('请输入密码后连接').catch(() => undefined);
      return;
    }

    const draft: ConnectionDraft = {
      host: host.trim(),
      port: portValue,
      username: username.trim(),
      password,
      isEditing,
      editingId: initial.editingId
    };

    setSubmitting(true);
    try {
      const record = await KesshHost.addConnection(draft);
      const settings = await KesshHost.getSettings().catch(() => null);
      if (settings?.savePassword) {
        await KesshHost.savePassword(record.id, password).catch(() => undefined);
      }
      navigator.replace('Terminal', { recordId: record.id, password });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      await KesshHost.showToast(`保存失败: ${message}`).catch(() => undefined);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <KeyboardAwareRoot>
      <KeyboardAwareResponder as="ScrollView" className="page">
        <PageHeader title={isEditing ? '输入密码' : '添加主机'} />

        <view style={{ padding: 16, gap: 12 }}>
          <KeyboardAwareTrigger>
            <view className="form-field">
              <text className="form-field-label">主机地址 (IP 或域名)</text>
              <Input
                className="form-field-input"
                value={host}
                placeholder="example.com 或 192.168.1.10"
                onInput={(value) => setHost(value)}
              />
            </view>
          </KeyboardAwareTrigger>

          <view className="form-field-row">
            <KeyboardAwareTrigger>
              <view className="form-field" style={{ flex: 1 }}>
                <text className="form-field-label">端口</text>
                <Input
                  className="form-field-input"
                  value={port}
                  placeholder="22"
                  type="number"
                  onInput={(value) => setPort(value)}
                />
              </view>
            </KeyboardAwareTrigger>
            <KeyboardAwareTrigger>
              <view className="form-field" style={{ flex: 2 }}>
                <text className="form-field-label">用户名</text>
                <Input
                  className="form-field-input"
                  value={username}
                  placeholder="root"
                  onInput={(value) => setUsername(value)}
                />
              </view>
            </KeyboardAwareTrigger>
          </view>

          <KeyboardAwareTrigger>
            <view className="form-field">
              <text className="form-field-label">密码</text>
              <Input
                className="form-field-input"
                value={password}
                placeholder="必填"
                type="password"
                onInput={(value) => setPassword(value)}
              />
            </view>
          </KeyboardAwareTrigger>

          <PrimaryAction
            label={submitting ? '正在连接…' : '保存并连接'}
            onTap={saveAndConnect}
            disabled={submitting}
          />
        </view>
      </KeyboardAwareResponder>
    </KeyboardAwareRoot>
  );
}
