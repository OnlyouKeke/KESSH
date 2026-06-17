import { Card, EmptyState, PageHeader, PrimaryAction } from '../components/Page';
import { useNavigator } from '../navigation/Navigator';
import { useConnections } from '../native/hooks';
import { KesshHost } from '../native/host';
import type { ConnectionRecord } from '../native/host';

export function HostListPage() {
  const navigator = useNavigator();
  const { data: connections, loading, error, reload } = useConnections();

  const handleConnect = async (record: ConnectionRecord) => {
    if (record.authType === 'key') {
      await KesshHost.showToast('密钥认证暂未支持').catch(() => undefined);
      return;
    }
    const hasPassword = await KesshHost.hasPassword(record.id).catch(() => false);
    if (!hasPassword) {
      navigator.push('AddHost', {
        editingId: record.id,
        host: record.host,
        port: record.port,
        username: record.username
      });
      return;
    }
    navigator.push('Terminal', { recordId: record.id });
  };

  return (
    <view className="page">
      <PageHeader title="主机列表" />

      {loading ? (
        <EmptyState title="加载中..." />
      ) : error ? (
        <EmptyState title={`数据源不可用 (${error.message})`} />
      ) : (connections ?? []).length === 0 ? (
        <EmptyState
          title="暂无主机"
          action={<PrimaryAction label="添加主机" onTap={() => navigator.push('AddHost')} />}
        />
      ) : (
        <view style={{ padding: 16, gap: 12 }}>
          {(connections ?? []).map((record) => (
            <Card key={record.id} onTap={() => handleConnect(record)}>
              <view className="card-row">
                <view style={{ flex: 1 }}>
                  <text className="card-title">{record.name}</text>
                  <text className="card-subtitle">{record.username} • {record.time}</text>
                </view>
                <text className="card-subtitle" style={{ color: 'var(--primary)' }}>连接</text>
              </view>
            </Card>
          ))}
        </view>
      )}

      <view className="action-bar">
        <Card className="card-tappable" onTap={reload}>
          <text className="card-title">刷新</text>
        </Card>
        <PrimaryAction label="添加主机" onTap={() => navigator.push('AddHost')} />
      </view>
    </view>
  );
}
