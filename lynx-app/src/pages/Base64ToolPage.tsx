import { TextArea } from '@lynx-js/lynx-ui';
import { useState } from '@lynx-js/react';

import { Card, PageHeader, PrimaryAction } from '../components/Page';
import { KesshHost } from '../native/host';

function timestamp(): string {
  const date = new Date();
  const pad = (value: number) => value.toString().padStart(2, '0');
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

function utf8Encode(input: string): Uint8Array {
  if (typeof TextEncoder !== 'undefined') {
    return new TextEncoder().encode(input);
  }
  // Fallback (Lynx environments without TextEncoder may go through host).
  const bytes: number[] = [];
  for (let i = 0; i < input.length; i++) {
    const code = input.charCodeAt(i);
    if (code < 0x80) {
      bytes.push(code);
    } else if (code < 0x800) {
      bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
    } else {
      bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
    }
  }
  return new Uint8Array(bytes);
}

const BASE64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function base64Encode(input: string): string {
  const bytes = utf8Encode(input);
  let result = '';
  let i = 0;
  while (i < bytes.length) {
    const a = bytes[i++];
    const b = i < bytes.length ? bytes[i++] : -1;
    const c = i < bytes.length ? bytes[i++] : -1;
    const buffer = (a << 16) | ((b > -1 ? b : 0) << 8) | (c > -1 ? c : 0);
    result += BASE64_CHARS[(buffer >> 18) & 0x3f];
    result += BASE64_CHARS[(buffer >> 12) & 0x3f];
    result += b > -1 ? BASE64_CHARS[(buffer >> 6) & 0x3f] : '=';
    result += c > -1 ? BASE64_CHARS[buffer & 0x3f] : '=';
  }
  return result;
}

function base64Decode(input: string): string {
  const sanitized = input.replace(/[^A-Za-z0-9+/=]/g, '');
  const bytes: number[] = [];
  let i = 0;
  while (i < sanitized.length) {
    const a = BASE64_CHARS.indexOf(sanitized[i++] ?? '');
    const b = BASE64_CHARS.indexOf(sanitized[i++] ?? '');
    const c = BASE64_CHARS.indexOf(sanitized[i++] ?? '');
    const d = BASE64_CHARS.indexOf(sanitized[i++] ?? '');
    if (a < 0 || b < 0) continue;
    const buffer = (a << 18) | (b << 12) | ((c > -1 ? c : 0) << 6) | (d > -1 ? d : 0);
    bytes.push((buffer >> 16) & 0xff);
    if (c > -1 && sanitized[i - 2] !== '=') bytes.push((buffer >> 8) & 0xff);
    if (d > -1 && sanitized[i - 1] !== '=') bytes.push(buffer & 0xff);
  }
  if (typeof TextDecoder !== 'undefined') {
    return new TextDecoder('utf-8').decode(new Uint8Array(bytes));
  }
  let out = '';
  for (let j = 0; j < bytes.length; j++) out += String.fromCharCode(bytes[j]);
  return out;
}

export function Base64ToolPage() {
  const [plain, setPlain] = useState<string>('');
  const [encoded, setEncoded] = useState<string>('');
  const [status, setStatus] = useState<string>('');

  async function encode() {
    if (!plain) {
      await KesshHost.showToast('请输入待编码文本').catch(() => undefined);
      return;
    }
    try {
      const result = base64Encode(plain);
      setEncoded(result);
      setStatus(`[${timestamp()}] 编码成功`);
      await KesshHost.showToast('编码成功').catch(() => undefined);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setStatus(`[${timestamp()}] 编码失败: ${message}`);
    }
  }

  async function decode() {
    if (!encoded) {
      await KesshHost.showToast('请输入待解码文本').catch(() => undefined);
      return;
    }
    try {
      const result = base64Decode(encoded);
      setPlain(result);
      setStatus(`[${timestamp()}] 解码成功`);
      await KesshHost.showToast('解码成功').catch(() => undefined);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setStatus(`[${timestamp()}] 解码失败: ${message}`);
    }
  }

  function clearAll() {
    setPlain('');
    setEncoded('');
    setStatus('');
  }

  return (
    <view className="page">
      <PageHeader title="Base64 编解码" trailing={<PrimaryAction label="清空" onTap={clearAll} />} />

      <view style={{ padding: 16, gap: 16 }}>
        <Card>
          <text className="card-title">🔐 Base64 转换工具</text>
          <text className="card-subtitle">本地完成字符串编解码，所有数据仅在设备上处理</text>
        </Card>

        <view className="form-field">
          <text className="form-field-label">原文 ({plain.length} 字符)</text>
          <TextArea
            className="form-field-input"
            value={plain}
            placeholder="输入待编码的文本内容…"
            onInput={(value) => setPlain(value)}
          />
        </view>
        <PrimaryAction label="编码 →" onTap={encode} />

        <view className="form-field">
          <text className="form-field-label">Base64 文本 ({encoded.length} 字符)</text>
          <TextArea
            className="form-field-input"
            value={encoded}
            placeholder="输入待解码的 Base64 文本…"
            onInput={(value) => setEncoded(value)}
          />
        </view>
        <PrimaryAction label="← 解码" onTap={decode} />

        {status ? (
          <text className="card-subtitle" style={{ textAlign: 'center' }}>{status}</text>
        ) : null}
      </view>
    </view>
  );
}
