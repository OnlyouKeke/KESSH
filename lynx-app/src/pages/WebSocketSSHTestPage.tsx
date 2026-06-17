import { Input } from '@lynx-js/lynx-ui';
import { useState } from '@lynx-js/react';

import { Card, PageHeader, PrimaryAction } from '../components/Page';
import { KesshHost } from '../native/host';

interface SshConfigDraft {
  proxyUrl: string;
  host: string;
  port: string;
  username: string;
  password: string;
}

export function WebSocketSSHTestPage() {
  const [draft, setDraft] = useState<SshConfigDraft>({
    proxyUrl: 'ws://localhost:8080',
    host: '192.168.1.100',
    port: '22',
    username: 'root',
    password: ''
  });
  const [status, setStatus] = useState<string>('Disconnected');
  const [output, setOutput] = useState<string>('');
  const [command, setCommand] = useState<string>('');
  const [connected, setConnected] = useState<boolean>(false);
  const [socket, setSocket] = useState<WebSocket | null>(null);

  function append(text: string) {
    setOutput((current) => current + text);
  }

  function connect() {
    if (connected) return;
    if (typeof WebSocket === 'undefined') {
      KesshHost.showToast('当前 Lynx 运行环境暂不支持 WebSocket').catch(() => undefined);
      return;
    }
    const port = parseInt(draft.port, 10);
    if (Number.isNaN(port) || port < 1 || port > 65535) {
      append('\n[ERROR] Invalid port number\n');
      return;
    }
    setStatus('Connecting...');
    append(`\n[INFO] Connecting to ${draft.host}:${port} via ${draft.proxyUrl}\n`);
    try {
      const ws = new WebSocket(draft.proxyUrl);
      ws.onopen = () => {
        ws.send(JSON.stringify({ type: 'connect', host: draft.host, port, username: draft.username, password: draft.password }));
      };
      ws.onmessage = (event) => {
        try {
          const payload = typeof event.data === 'string' ? JSON.parse(event.data) : { type: 'data', data: '' };
          if (payload.type === 'data') {
            append(payload.data || '');
          } else if (payload.type === 'connected') {
            setStatus('Connected');
            setConnected(true);
            append('\n[INFO] SSH connection established\n');
          } else if (payload.type === 'error') {
            append(`\n[ERROR] ${payload.message ?? 'unknown'}\n`);
          }
        } catch {
          if (typeof event.data === 'string') append(event.data);
        }
      };
      ws.onerror = () => {
        setStatus('Error');
        append('\n[ERROR] WebSocket error\n');
      };
      ws.onclose = (event) => {
        setStatus(`Closed: ${event.code}`);
        setConnected(false);
        setSocket(null);
        append('\n[INFO] SSH connection closed\n');
      };
      setSocket(ws);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setStatus(`Connection failed: ${message}`);
      append(`\n[ERROR] ${message}\n`);
    }
  }

  function disconnect() {
    if (!socket) return;
    socket.close();
  }

  function send() {
    if (!socket || !connected) {
      append('\n[WARN] Not connected\n');
      return;
    }
    if (!command.trim()) return;
    append(`$ ${command}\n`);
    socket.send(JSON.stringify({ type: 'data', data: `${command}\n` }));
    setCommand('');
  }

  function clear() {
    setOutput('');
  }

  function update<K extends keyof SshConfigDraft>(key: K, value: string) {
    setDraft((current) => ({ ...current, [key]: value }));
  }

  return (
    <view className="page">
      <PageHeader title="WebSocket SSH 测试" />

      <view style={{ padding: 16, gap: 12 }}>
        <Card>
          <text className="card-title">Status: {status}</text>
        </Card>
        <view className="form-field">
          <text className="form-field-label">代理地址</text>
          <Input className="form-field-input" value={draft.proxyUrl} onInput={(value) => update('proxyUrl', value)} />
        </view>
        <view className="form-field-row">
          <view className="form-field" style={{ flex: 2 }}>
            <text className="form-field-label">SSH 主机</text>
            <Input className="form-field-input" value={draft.host} onInput={(value) => update('host', value)} />
          </view>
          <view className="form-field" style={{ flex: 1 }}>
            <text className="form-field-label">端口</text>
            <Input className="form-field-input" value={draft.port} type="number" onInput={(value) => update('port', value)} />
          </view>
        </view>
        <view className="form-field">
          <text className="form-field-label">用户名</text>
          <Input className="form-field-input" value={draft.username} onInput={(value) => update('username', value)} />
        </view>
        <view className="form-field">
          <text className="form-field-label">密码</text>
          <Input className="form-field-input" value={draft.password} type="password" onInput={(value) => update('password', value)} />
        </view>

        <view className="form-field-row">
          <PrimaryAction label="Connect" onTap={connect} disabled={connected} />
          <PrimaryAction label="Disconnect" onTap={disconnect} disabled={!connected} />
        </view>
      </view>

      <scroll-view scroll-y style={{ flex: 1, padding: 16, backgroundColor: 'var(--canvas-ambient)' }}>
        <text style={{ fontFamily: 'monospace', fontSize: 12 }}>{output}</text>
      </scroll-view>

      <view className="action-bar">
        <view className="form-field" style={{ flex: 1 }}>
          <Input
            className="form-field-input"
            value={command}
            placeholder="输入命令"
            onInput={(value) => setCommand(value)}
            onConfirm={() => send()}
          />
        </view>
        <PrimaryAction label="Send" onTap={send} disabled={!connected} />
        <view className="btn-ghost" bindtap={clear}>
          <text className="btn-ghost-text">Clear</text>
        </view>
      </view>
    </view>
  );
}
