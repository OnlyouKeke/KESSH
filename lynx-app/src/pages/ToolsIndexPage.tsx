import { Card, PageHeader } from '../components/Page';
import { useNavigator } from '../navigation/Navigator';
import type { RouteName } from '../navigation/Navigator';

const TOOLS: { key: RouteName; title: string; subtitle: string; icon: string }[] = [
  { key: 'PingTool', title: 'Ping 工具', subtitle: '测试到指定主机的网络连通性', icon: '🌐' },
  { key: 'PortTest', title: '端口测试', subtitle: '验证指定主机端口是否开放', icon: '🔌' },
  { key: 'Base64Tool', title: 'Base64 编解码', subtitle: '本地完成字符串编解码', icon: '🔐' },
  { key: 'SubnetCalc', title: '子网掩码计算器', subtitle: '快速计算网络/广播地址、主机范围', icon: '🔢' }
];

export function ToolsIndexPage() {
  const navigator = useNavigator();
  return (
    <view className="page">
      <PageHeader title="工具" />
      <view style={{ padding: 16, gap: 12 }}>
        {TOOLS.map((tool) => (
          <Card key={tool.key} onTap={() => navigator.push(tool.key)}>
            <view className="card-row">
              <text style={{ fontSize: 22, marginRight: 12 }}>{tool.icon}</text>
              <view style={{ flex: 1 }}>
                <text className="card-title">{tool.title}</text>
                <text className="card-subtitle">{tool.subtitle}</text>
              </view>
              <text className="card-subtitle">{'>'}</text>
            </view>
          </Card>
        ))}
      </view>
    </view>
  );
}
