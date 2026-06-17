import { Input } from '@lynx-js/lynx-ui';
import { useState } from '@lynx-js/react';

import { Card, PageHeader, PrimaryAction } from '../components/Page';
import { KesshHost } from '../native/host';

export function WebSocketTestPage() {
  const [url, setUrl] = useState<string>('ws://localhost:8080');
  const [status, setStatus] = useState<string>('Disconnected');
  const [messages, setMessages] = useState<string[]>([]);
  const [input, setInput] = useState<string>('');
  const [connected, setConnected] = useState<boolean>(false);
  const [socket, setSocket] = useState<WebSocket | null>(null);

  function append(line: string) {
    setMessages((current) => [...current, line]);
  }

  function connect() {
    if (connected) return;
    if (typeof WebSocket === 'undefined') {
      KesshHost.showToast('当前 Lynx 运行环境暂不支持 WebSocket').catch(() => undefined);
      return;
    }
    setStatus('Connecting...');
    append(`Connecting to ${url}`);
    try {
      const ws = new WebSocket(url);
      ws.onopen = () => {
        setStatus('Connected');
        setConnected(true);
        append('Connected successfully');
      };
      ws.onmessage = (event) => {
        const data = typeof event.data === 'string' ? event.data : '[Binary Data]';
        append(`Received: ${data}`);
      };
      ws.onerror = () => {
        setStatus('Error');
        append('Error encountered');
      };
      ws.onclose = (event) => {
        setStatus(`Closed: ${event.code} - ${event.reason}`);
        setConnected(false);
        setSocket(null);
      };
      setSocket(ws);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setStatus(`Connection failed: ${message}`);
      append(`Connection failed: ${message}`);
    }
  }

  function disconnect() {
    if (!socket) return;
    socket.close();
  }

  function send() {
    if (!socket || !connected) {
      append('Not connected');
      return;
    }
    if (!input.trim()) {
      append('Please enter a message');
      return;
    }
    socket.send(input);
    append(`Sent: ${input}`);
    setInput('');
  }

  return (
    <view className="page">
      <PageHeader title="WebSocket 测试" />

      <view style={{ padding: 16, gap: 12 }}>
        <Card>
          <text className="card-title">Status: {status}</text>
        </Card>
        <view className="form-field">
          <text className="form-field-label">Server URL</text>
          <Input className="form-field-input" value={url} onInput={(value) => setUrl(value)} />
        </view>
        <view className="form-field-row">
          <PrimaryAction label="Connect" onTap={connect} disabled={connected} />
          <PrimaryAction label="Disconnect" onTap={disconnect} disabled={!connected} />
        </view>
        <view className="form-field">
          <text className="form-field-label">Message</text>
          <Input className="form-field-input" value={input} onInput={(value) => setInput(value)} />
        </view>
        <PrimaryAction label="Send" onTap={send} disabled={!connected} />
      </view>

      <scroll-view scroll-y style={{ flex: 1, padding: 16 }}>
        {messages.map((line, index) => (
          <text key={`${index}`} className="terminal-line">{line}</text>
        ))}
      </scroll-view>
    </view>
  );
}
