import { ScrollView } from '@lynx-js/lynx-ui';

import { Card, EmptyState, PageHeader, SectionTitle } from '../components/Page';
import { useNavigator } from '../navigation/Navigator';
import { useConnections } from '../native/hooks';
import { KesshHost } from '../native/host';
import type { ConnectionRecord } from '../native/host';

const VAULT_ITEMS: { key: 'hosts' | 'keys' | 'snippets'; title: string; subtitle: string; icon: string; route: 'HostList' | 'SettingsKeys' | 'Snippets' }[] = [
  { key: 'hosts', title: '主机', subtitle: '管理 SSH 主机和保存的会话', icon: '💻', route: 'HostList' },
  { key: 'keys', title: '密钥管理', subtitle: '本地密钥与身份管理', icon: '🔑', route: 'SettingsKeys' },
  { key: 'snippets', title: '代码片段', subtitle: '复用常用命令', icon: '🧞', route: 'Snippets' }
];

function RecentConnectionRow({ record, onTap }: { record: ConnectionRecord; onTap: () => void }) {
  return (
    <view className="card card-tappable" bindtap={onTap}>
      <view className="card-row">
        <view style={{ flex: 1 }}>
          <text className="card-title">{record.name}</text>
          <text className="card-subtitle">{record.time}</text>
        </view>
        <text className="card-subtitle">🚀</text>
      </view>
    </view>
  );
}

export function HistoryPage() {
  const navigator = useNavigator();
  const { data: connections, error } = useConnections();

  const recent = (connections ?? []).slice(0, 3);

  const handleConnect = async (record: ConnectionRecord) => {
    if (record.authType === 'key') {
      await KesshHost.showToast('密钥认证暂未支持').catch(() => undefined);
      return;
    }
    const hasPassword = await KesshHost.hasPassword(record.id).catch(() => false);
    if (!hasPassword) {
      await KesshHost.showToast('请输入密码后连接').catch(() => undefined);
      navigator.push('AddHost', { editingId: record.id, host: record.host, port: record.port, username: record.username });
      return;
    }
    navigator.push('Terminal', { recordId: record.id });
  };

  return (
    <ScrollView className="page">
      <view className="page-header">
        <text className="page-title">资产</text>
      </view>

      {recent.length > 0 ? (
        <>
          <SectionTitle>最近连接</SectionTitle>
          <view style={{ padding: 16, gap: 12 }}>
            {recent.map((record) => (
              <RecentConnectionRow key={record.id} record={record} onTap={() => handleConnect(record)} />
            ))}
          </view>
        </>
      ) : null}

      <SectionTitle>资产管理</SectionTitle>
      <view style={{ padding: 16, gap: 12 }}>
        {VAULT_ITEMS.map((item) => (
          <Card key={item.key} onTap={() => navigator.push(item.route)}>
            <view className="card-row">
              <text style={{ fontSize: 20, marginRight: 12 }}>{item.icon}</text>
              <view style={{ flex: 1 }}>
                <text className="card-title">{item.title}</text>
                <text className="card-subtitle">{item.subtitle}</text>
              </view>
              <text className="card-subtitle">{'>'}</text>
            </view>
          </Card>
        ))}
      </view>

      {error ? (
        <EmptyState title={`未连接到 HarmonyOS 数据源 (${error.message})`} />
      ) : null}
    </ScrollView>
  );
}
