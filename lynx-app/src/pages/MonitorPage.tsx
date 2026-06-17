import { useEffect, useRef, useState } from '@lynx-js/react';

import { Card, EmptyState, PageHeader, PrimaryAction } from '../components/Page';
import { useNavigator } from '../navigation/Navigator';
import { useConnections } from '../native/hooks';
import { KesshHost } from '../native/host';
import type { ConnectionRecord, SystemMetrics } from '../native/host';

const HISTORY_LIMIT = 20;

function clamp(value: number): number {
  if (Number.isNaN(value)) return 0;
  if (value < 0) return 0;
  if (value > 100) return 100;
  return value;
}

function MetricBar({ label, usage, summary, history }: { label: string; usage: number; summary: string; history: number[] }) {
  const points = history.length > 0 ? history : [0];
  return (
    <Card>
      <view className="card-row">
        <text className="card-title">{label}</text>
        <text className="card-subtitle" style={{ color: 'var(--primary)' }}>{usage.toFixed(1)}%</text>
      </view>
      <view style={{ flexDirection: 'row', gap: 4, height: 100, marginTop: 8 }}>
        {points.map((value, index) => (
          <view
            key={`${index}-${value}`}
            style={{
              flex: 1,
              alignSelf: 'flex-end',
              height: `${clamp(value)}%`,
              backgroundColor: 'var(--primary)',
              opacity: 0.6,
              borderRadius: 3
            }}
          />
        ))}
      </view>
      <text className="card-subtitle" style={{ marginTop: 8 }}>{summary || '--'}</text>
    </Card>
  );
}

export function MonitorPage() {
  const navigator = useNavigator();
  const { data: hosts } = useConnections();
  const [selected, setSelected] = useState<ConnectionRecord | null>(null);
  const [metrics, setMetrics] = useState<SystemMetrics | null>(null);
  const [error, setError] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [cpuHistory, setCpuHistory] = useState<number[]>([]);
  const [memHistory, setMemHistory] = useState<number[]>([]);
  const [diskHistory, setDiskHistory] = useState<number[]>([]);
  const sessionRef = useRef<number>(-1);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const tokenRef = useRef<number>(0);
  const disposedRef = useRef<boolean>(false);

  useEffect(() => {
    return () => {
      disposedRef.current = true;
      tokenRef.current++;
      if (timerRef.current) clearInterval(timerRef.current);
      if (sessionRef.current > 0) KesshHost.closeSession(sessionRef.current).catch(() => undefined);
    };
  }, []);

  async function pickHost(record: ConnectionRecord) {
    if (record.authType === 'key') {
      await KesshHost.showToast('密钥认证暂未支持').catch(() => undefined);
      return;
    }
    const hasPwd = await KesshHost.hasPassword(record.id).catch(() => false);
    if (!hasPwd) {
      await KesshHost.showToast('请先为该主机启用保存密码').catch(() => undefined);
      navigator.push('AddHost', { editingId: record.id, host: record.host, port: record.port, username: record.username });
      return;
    }
    if (timerRef.current) clearInterval(timerRef.current);
    if (sessionRef.current > 0) await KesshHost.closeSession(sessionRef.current).catch(() => undefined);
    setSelected(record);
    setError('');
    setLoading(true);
    setCpuHistory([]);
    setMemHistory([]);
    setDiskHistory([]);

    const token = ++tokenRef.current;
    try {
      const sid = await KesshHost.openSession({
        host: record.host,
        port: record.port,
        username: record.username,
        editingId: record.id,
        isEditing: true
      });
      if (disposedRef.current || token !== tokenRef.current) {
        if (sid > 0) await KesshHost.closeSession(sid).catch(() => undefined);
        return;
      }
      if (sid <= 0) {
        setError('SSH 连接失败');
        return;
      }
      sessionRef.current = sid;
      await tick();
      timerRef.current = setInterval(() => { tick(); }, 5000);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message);
    } finally {
      setLoading(false);
    }
  }

  async function tick() {
    const sid = sessionRef.current;
    if (sid <= 0) return;
    try {
      const next = await KesshHost.fetchMetrics(sid);
      if (disposedRef.current) return;
      setMetrics(next);
      setCpuHistory((current) => [...current, clamp(next.cpuUsage)].slice(-HISTORY_LIMIT));
      setMemHistory((current) => [...current, clamp(next.memoryUsage)].slice(-HISTORY_LIMIT));
      setDiskHistory((current) => [...current, clamp(next.diskUsage)].slice(-HISTORY_LIMIT));
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message);
    }
  }

  return (
    <view className="page">
      <PageHeader title="服务器监控" trailing={<PrimaryAction label="刷新" onTap={tick} disabled={!selected || loading} />} />

      <view style={{ padding: 16, gap: 12 }}>
        {selected ? (
          <text className="card-subtitle">当前主机: {selected.name}</text>
        ) : (
          <text className="card-subtitle">请选择一台已保存密码的主机</text>
        )}
        {error ? <text className="card-subtitle" style={{ color: 'var(--primary)' }}>错误: {error}</text> : null}
      </view>

      {!selected ? (
        (hosts ?? []).length === 0 ? (
          <EmptyState title="无可用主机" />
        ) : (
          <view style={{ padding: 16, gap: 12 }}>
            {(hosts ?? []).map((record) => (
              <Card key={record.id} onTap={() => pickHost(record)}>
                <text className="card-title">{record.name}</text>
                <text className="card-subtitle">{record.host}:{record.port} · {record.username}</text>
              </Card>
            ))}
          </view>
        )
      ) : (
        <view style={{ padding: 16, gap: 12 }}>
          <MetricBar label="CPU 使用率" usage={metrics?.cpuUsage ?? 0} summary={metrics?.cpuDetail ?? '--'} history={cpuHistory} />
          <MetricBar label="内存使用率" usage={metrics?.memoryUsage ?? 0} summary={metrics?.memoryDetail ?? '--'} history={memHistory} />
          <MetricBar label="磁盘使用率" usage={metrics?.diskUsage ?? 0} summary={metrics?.diskDetail ?? '--'} history={diskHistory} />
          {metrics?.lastUpdate ? (
            <text className="card-subtitle">最近更新: {metrics.lastUpdate}</text>
          ) : null}
        </view>
      )}
    </view>
  );
}
