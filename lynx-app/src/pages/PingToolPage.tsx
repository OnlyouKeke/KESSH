import { Input } from '@lynx-js/lynx-ui';
import { useState } from '@lynx-js/react';

import { Card, PageHeader, PrimaryAction } from '../components/Page';
import { KesshHost } from '../native/host';

function timestamp(): string {
  const date = new Date();
  const pad = (value: number) => value.toString().padStart(2, '0');
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

export function PingToolPage() {
  const [host, setHost] = useState<string>('');
  const [count, setCount] = useState<string>('4');
  const [result, setResult] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);

  async function run() {
    const target = host.trim();
    if (!target) {
      await KesshHost.showToast('请输入需要 Ping 的主机').catch(() => undefined);
      return;
    }
    let n = parseInt(count, 10) || 4;
    if (n <= 0) n = 4;
    if (n > 10) n = 10;

    setLoading(true);
    setResult(`[${timestamp()}] 正在测试...`);
    try {
      const output = await KesshHost.pingHost(target, n);
      setResult(`[${timestamp()}]\n${output}`);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setResult(`[${timestamp()}] Ping 执行失败: ${message}`);
    } finally {
      setLoading(false);
    }
  }

  async function copy() {
    if (!result) return;
    await KesshHost.writeClipboard(result).catch(() => undefined);
    await KesshHost.showToast('结果已复制').catch(() => undefined);
  }

  return (
    <view className="page">
      <PageHeader title="Ping 工具" />

      <view style={{ padding: 16, gap: 16 }}>
        <Card>
          <text className="card-title">🌐 网络连通性检测</text>
          <text className="card-subtitle">快速测试到指定主机的网络延迟和连通性，支持域名和 IP 地址</text>
        </Card>

        <view className="form-field">
          <text className="form-field-label">主机或 IP</text>
          <Input
            className="form-field-input"
            value={host}
            placeholder="例如 baidu.com"
            onInput={(value) => setHost(value)}
          />
        </view>

        <view className="form-field-row">
          <view className="form-field" style={{ flex: 1 }}>
            <text className="form-field-label">次数 (1-10)</text>
            <Input
              className="form-field-input"
              value={count}
              type="number"
              onInput={(value) => setCount(value)}
            />
          </view>
          <PrimaryAction
            label={loading ? '测试中…' : '开始 Ping'}
            onTap={run}
            disabled={loading}
          />
        </view>

        {result ? (
          <Card>
            <view className="card-row">
              <text className="card-title">输出结果</text>
              <view className="btn-ghost" bindtap={copy}>
                <text className="btn-ghost-text">复制</text>
              </view>
            </view>
            <text className="terminal-line" style={{ fontFamily: 'monospace' }}>{result}</text>
          </Card>
        ) : null}
      </view>
    </view>
  );
}
