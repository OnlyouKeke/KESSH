import { Card, EmptyState, PageHeader, PrimaryAction } from '../components/Page';
import { useLogs } from '../native/hooks';
import { KesshHost } from '../native/host';

export function SettingsLogsPage() {
  const { data, loading, error, reload } = useLogs();

  async function clear() {
    await KesshHost.clearLogs().catch(() => undefined);
    reload();
  }

  return (
    <view className="page">
      <PageHeader title="日志" trailing={<PrimaryAction label="清空" onTap={clear} />} />

      {loading ? (
        <EmptyState title="加载中..." />
      ) : error ? (
        <EmptyState title={`数据源不可用 (${error.message})`} />
      ) : (data ?? []).length === 0 ? (
        <EmptyState title="暂无日志" />
      ) : (
        <scroll-view scroll-y style={{ flex: 1, padding: 16 }}>
          {(data ?? []).map((line, index) => (
            <text key={`${index}`} className="terminal-line">{line}</text>
          ))}
        </scroll-view>
      )}
    </view>
  );
}
