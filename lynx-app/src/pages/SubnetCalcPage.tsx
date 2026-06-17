import { Input, KeyboardAwareTrigger } from '@lynx-js/lynx-ui';
import { useState } from '@lynx-js/react';

import { Card, PageHeader, PrimaryAction } from '../components/Page';
import { KeyboardAwarePage } from '../components/KeyboardAwarePage';
import { KesshHost } from '../native/host';

interface SubnetResult {
  network: string;
  broadcast: string;
  firstHost: string;
  lastHost: string;
  mask: string;
  totalHosts: number;
  usableHosts: number;
  ipClass: string;
  isPrivate: boolean;
}

function calculate(ip: string, maskBits: number): SubnetResult | null {
  const parts = ip.split('.');
  if (parts.length !== 4) return null;
  const octets = parts.map((part) => parseInt(part, 10));
  if (octets.some((value) => Number.isNaN(value) || value < 0 || value > 255)) return null;

  const mask = (0xffffffff << (32 - maskBits)) >>> 0;
  const maskOctets = [(mask >>> 24) & 0xff, (mask >>> 16) & 0xff, (mask >>> 8) & 0xff, mask & 0xff];
  const ipNum = octets.reduce((accumulator, value) => (accumulator << 8) + value, 0) >>> 0;
  const networkNum = (ipNum & mask) >>> 0;
  const broadcastNum = (networkNum | (~mask & 0xffffffff)) >>> 0;
  const firstHostNum = networkNum + 1;
  const lastHostNum = broadcastNum - 1;

  const toDotted = (value: number) =>
    `${(value >>> 24) & 0xff}.${(value >>> 16) & 0xff}.${(value >>> 8) & 0xff}.${value & 0xff}`;

  const totalHosts = Math.pow(2, 32 - maskBits);
  const usableHosts = maskBits === 32 ? 1 : maskBits === 31 ? 2 : totalHosts - 2;

  let ipClass = '';
  const first = octets[0];
  if (first >= 1 && first <= 126) ipClass = 'A 类';
  else if (first >= 128 && first <= 191) ipClass = 'B 类';
  else if (first >= 192 && first <= 223) ipClass = 'C 类';
  else if (first >= 224 && first <= 239) ipClass = 'D 类(组播)';
  else if (first >= 240 && first <= 255) ipClass = 'E 类(保留)';

  let isPrivate = false;
  if (first === 10) isPrivate = true;
  else if (first === 172 && octets[1] >= 16 && octets[1] <= 31) isPrivate = true;
  else if (first === 192 && octets[1] === 168) isPrivate = true;

  return {
    network: toDotted(networkNum),
    broadcast: toDotted(broadcastNum),
    firstHost: toDotted(firstHostNum),
    lastHost: toDotted(lastHostNum),
    mask: maskOctets.join('.'),
    totalHosts,
    usableHosts,
    ipClass,
    isPrivate
  };
}

export function SubnetCalcPage() {
  const [ip, setIp] = useState<string>('');
  const [maskText, setMaskText] = useState<string>('24');
  const [result, setResult] = useState<SubnetResult | null>(null);
  const [error, setError] = useState<string>('');

  async function run() {
    const trimmed = ip.trim();
    if (!trimmed) {
      await KesshHost.showToast('请输入 IP 地址').catch(() => undefined);
      return;
    }
    let bits = parseInt(maskText, 10);
    if (Number.isNaN(bits)) bits = 24;
    if (bits < 0) bits = 0;
    if (bits > 32) bits = 32;

    const next = calculate(trimmed, bits);
    if (!next) {
      setError('IP 地址格式错误');
      setResult(null);
      return;
    }
    setError('');
    setResult(next);
  }

  async function copy() {
    if (!result) return;
    const text = [
      `IP 地址: ${ip}`,
      `子网掩码: ${result.mask} (/${maskText})`,
      `网络地址: ${result.network}`,
      `广播地址: ${result.broadcast}`,
      `主机范围: ${result.firstHost} - ${result.lastHost}`,
      `总 IP 数: ${result.totalHosts}`,
      `可用主机数: ${result.usableHosts}`,
      `IP 类别: ${result.ipClass}`,
      `地址类型: ${result.isPrivate ? '私有地址' : '公网地址'}`
    ].join('\n');
    await KesshHost.writeClipboard(text).catch(() => undefined);
    await KesshHost.showToast('结果已复制').catch(() => undefined);
  }

  return (
    <KeyboardAwarePage>
      <PageHeader title="子网掩码计算器" />

      <view style={{ padding: 16, gap: 16 }}>
        <Card>
          <text className="card-title">🔢 子网信息计算</text>
          <text className="card-subtitle">根据 IP 地址和子网掩码位数自动计算网络/广播地址、主机范围等信息</text>
        </Card>

        <KeyboardAwareTrigger>
          <view className="form-field">
            <text className="form-field-label">IP 地址</text>
            <Input className="form-field-input" value={ip} placeholder="例如 192.168.1.100" onInput={(value) => setIp(value)} />
          </view>
        </KeyboardAwareTrigger>
        <view className="form-field-row">
          <KeyboardAwareTrigger>
            <view className="form-field" style={{ flex: 1 }}>
              <text className="form-field-label">掩码位数 (0-32)</text>
              <Input className="form-field-input" value={maskText} type="number" onInput={(value) => setMaskText(value)} />
            </view>
          </KeyboardAwareTrigger>
          <PrimaryAction label="开始计算" onTap={run} />
        </view>

        {error ? <text className="card-subtitle" style={{ color: 'var(--primary)' }}>{error}</text> : null}

        {result ? (
          <Card>
            <view className="card-row">
              <text className="card-title">计算结果</text>
              <view className="btn-ghost" bindtap={copy}>
                <text className="btn-ghost-text">复制</text>
              </view>
            </view>
            <text className="card-subtitle">IP 地址: {ip}</text>
            <text className="card-subtitle">子网掩码: {result.mask} (/{maskText})</text>
            <text className="card-subtitle">网络地址: {result.network}</text>
            <text className="card-subtitle">广播地址: {result.broadcast}</text>
            <text className="card-subtitle">主机范围: {result.firstHost} - {result.lastHost}</text>
            <text className="card-subtitle">总 IP 数: {result.totalHosts}</text>
            <text className="card-subtitle">可用主机数: {result.usableHosts}</text>
            <text className="card-subtitle">IP 类别: {result.ipClass}</text>
            <text className="card-subtitle">地址类型: {result.isPrivate ? '私有地址' : '公网地址'}</text>
          </Card>
        ) : null}
      </view>
    </KeyboardAwarePage>
  );
}
