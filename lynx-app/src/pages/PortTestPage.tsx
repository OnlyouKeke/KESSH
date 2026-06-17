import { Input, KeyboardAwareTrigger } from '@lynx-js/lynx-ui';
import { useState } from '@lynx-js/react';

import { Card, PageHeader, PrimaryAction } from '../components/Page';
import { KeyboardAwarePage } from '../components/KeyboardAwarePage';
import { KesshHost } from '../native/host';

function timestamp(): string {
  const date = new Date();
  const pad = (value: number) => value.toString().padStart(2, '0');
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

export function PortTestPage() {
  const [host, setHost] = useState<string>('');
  const [port, setPort] = useState<string>('22');
  const [timeoutMs, setTimeoutMs] = useState<string>('3000');
  const [result, setResult] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);

  async function run() {
    const target = host.trim();
    const portValue = parseInt(port, 10);
    if (!target || !portValue || portValue <= 0 || portValue > 65535) {
      await KesshHost.showToast('请填写有效的主机与端口').catch(() => undefined);
      return;
    }
    let t = parseInt(timeoutMs, 10);
    if (!t || t < 1000) t = 1000;
    if (t > 15000) t = 15000;

    setLoading(true);
    setResult(`[${timestamp()}] 正在连接 ${target}:${portValue}...`);
    try {
      const output = await KesshHost.testPort(target, portValue, t);
      setResult(`[${timestamp()}]\n${output}`);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setResult(`[${timestamp()}] 端口不可用: ${message}`);
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
    <KeyboardAwarePage>
      <PageHeader title="端口测试" />

      <view style={{ padding: 16, gap: 16 }}>
        <Card>
          <text className="card-title">🔌 端口可用性检测</text>
          <text className="card-subtitle">验证指定主机的端口是否开放，常用于检测 SSH(22)、HTTP(80)、HTTPS(443) 等服务</text>
        </Card>

        <KeyboardAwareTrigger>
          <view className="form-field">
            <text className="form-field-label">主机或 IP</text>
            <Input
              className="form-field-input"
              value={host}
              placeholder="主机或 IP 地址"
              onInput={(value) => setHost(value)}
            />
          </view>
        </KeyboardAwareTrigger>

        <view className="form-field-row">
          <KeyboardAwareTrigger>
            <view className="form-field" style={{ flex: 1 }}>
              <text className="form-field-label">端口号</text>
              <Input
                className="form-field-input"
                value={port}
                type="number"
                onInput={(value) => setPort(value)}
              />
            </view>
          </KeyboardAwareTrigger>
          <KeyboardAwareTrigger>
            <view className="form-field" style={{ flex: 1 }}>
              <text className="form-field-label">超时 (ms)</text>
              <Input
                className="form-field-input"
                value={timeoutMs}
                type="number"
                onInput={(value) => setTimeoutMs(value)}
              />
            </view>
          </KeyboardAwareTrigger>
        </view>

        <PrimaryAction
          label={loading ? '测试中…' : '开始测试'}
          onTap={run}
          disabled={loading}
        />

        <Card>
          <text className="card-title">常用端口参考</text>
          <text className="card-subtitle">SSH:22 · HTTP:80 · HTTPS:443</text>
          <text className="card-subtitle">FTP:21 · MySQL:3306 · Redis:6379</text>
        </Card>

        {result ? (
          <Card>
            <view className="card-row">
              <text className="card-title">测试结果</text>
              <view className="btn-ghost" bindtap={copy}>
                <text className="btn-ghost-text">复制</text>
              </view>
            </view>
            <text className="terminal-line" style={{ fontFamily: 'monospace' }}>{result}</text>
          </Card>
        ) : null}
      </view>
    </KeyboardAwarePage>
  );
}
