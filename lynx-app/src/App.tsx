import { useEffect, useState } from '@lynx-js/react';
import type { ReactNode } from '@lynx-js/react';
import { clsx } from 'clsx';

import { NavigatorProvider, useNavigator } from './navigation/Navigator';
import { KesshHost } from './native/host';

import { HistoryPage } from './pages/HistoryPage';
import { HostListPage } from './pages/HostListPage';
import { AddHostPage } from './pages/AddHostPage';
import { SettingsPage } from './pages/SettingsPage';
import { TerminalPage } from './pages/TerminalPage';
import { SnippetsPage } from './pages/SnippetsPage';
import { SFTPPage } from './pages/SFTPPage';
import { SettingsKeysPage } from './pages/SettingsKeysPage';
import { SettingsLogsPage } from './pages/SettingsLogsPage';
import { SettingsSessionPage } from './pages/SettingsSessionPage';
import { SettingsTerminalFontPage } from './pages/SettingsTerminalFontPage';
import { MonitorPage } from './pages/MonitorPage';
import { SCPPage } from './pages/SCPPage';
import { PrivacyPolicyPage } from './pages/PrivacyPolicyPage';
import { UserAgreementPage } from './pages/UserAgreementPage';
import { FeedbackPage } from './pages/FeedbackPage';
import { ToolsIndexPage } from './pages/ToolsIndexPage';
import { PingToolPage } from './pages/PingToolPage';
import { PortTestPage } from './pages/PortTestPage';
import { Base64ToolPage } from './pages/Base64ToolPage';
import { SubnetCalcPage } from './pages/SubnetCalcPage';
import { WebSocketTestPage } from './pages/WebSocketTestPage';
import { WebSocketSSHTestPage } from './pages/WebSocketSSHTestPage';

import './styles/theme.css';

const TABS: { key: 'history' | 'connect' | 'settings'; label: string }[] = [
  { key: 'history', label: '资产' },
  { key: 'connect', label: '连接' },
  { key: 'settings', label: '设置' }
];

function ConnectTab() {
  const navigator = useNavigator();
  const items: { title: string; subtitle: string; route: 'AddHost' | 'SFTPPage' | 'Monitor' | 'SCPPage'; icon: string }[] = [
    { title: '添加主机', subtitle: '通过 SSH 连接到远程机器', route: 'AddHost', icon: '🔑' },
    { title: 'SFTP 文件浏览', subtitle: '通过 SSH 浏览远程文件目录', route: 'SFTPPage', icon: '📦' },
    { title: 'SCP 文件传输', subtitle: '上传 / 下载远程文件', route: 'SCPPage', icon: '🚚' },
    { title: '服务器监控', subtitle: '实时查看 CPU / 内存 / 磁盘', route: 'Monitor', icon: '📈' }
  ];
  return (
    <view className="page">
      <view className="page-header">
        <text className="page-title">连接</text>
      </view>
      <view style={{ padding: 16, gap: 12 }}>
        {items.map((item) => (
          <view
            key={item.route}
            className="card card-tappable"
            bindtap={() => navigator.push(item.route)}
          >
            <view className="card-row">
              <text style={{ fontSize: 22, marginRight: 12 }}>{item.icon}</text>
              <view style={{ flex: 1 }}>
                <text className="card-title">{item.title}</text>
                <text className="card-subtitle">{item.subtitle}</text>
              </view>
              <text className="card-subtitle">{'>'}</text>
            </view>
          </view>
        ))}
      </view>
    </view>
  );
}

function TabBar({ active, onChange }: { active: string; onChange: (key: 'history' | 'connect' | 'settings') => void }) {
  return (
    <view className="tab-bar">
      {TABS.map((tab) => (
        <view
          key={tab.key}
          className={clsx('tab-bar-item', { active: active === tab.key })}
          bindtap={() => onChange(tab.key)}
        >
          <text className="tab-bar-item-text">{tab.label}</text>
        </view>
      ))}
    </view>
  );
}

function HomeShell() {
  const [tab, setTab] = useState<'history' | 'connect' | 'settings'>('history');
  let body: ReactNode;
  switch (tab) {
    case 'history':
      body = <HistoryPage />;
      break;
    case 'connect':
      body = <ConnectTab />;
      break;
    case 'settings':
      body = <SettingsPage />;
      break;
  }
  return (
    <view className="page">
      <view style={{ flex: 1 }}>{body}</view>
      <TabBar active={tab} onChange={setTab} />
    </view>
  );
}

function CurrentRoute() {
  const navigator = useNavigator();
  const route = navigator.current;
  switch (route.name) {
    case 'Home':
      return <HomeShell />;
    case 'AddHost':
      return <AddHostPage params={route.params} />;
    case 'HostList':
      return <HostListPage />;
    case 'HistoryPage':
      return <HistoryPage />;
    case 'Snippets':
      return <SnippetsPage />;
    case 'SettingsPage':
      return <SettingsPage />;
    case 'SettingsKeys':
      return <SettingsKeysPage />;
    case 'SettingsLogs':
      return <SettingsLogsPage />;
    case 'SettingsSession':
      return <SettingsSessionPage />;
    case 'SettingsTerminalFont':
      return <SettingsTerminalFontPage />;
    case 'Terminal':
      return <TerminalPage params={route.params} />;
    case 'SFTPPage':
      return <SFTPPage />;
    case 'Monitor':
      return <MonitorPage />;
    case 'SCPPage':
      return <SCPPage params={route.params} />;
    case 'PrivacyPolicy':
      return <PrivacyPolicyPage />;
    case 'UserAgreement':
      return <UserAgreementPage />;
    case 'Feedback':
      return <FeedbackPage />;
    case 'Tools':
      return <ToolsIndexPage />;
    case 'PingTool':
      return <PingToolPage />;
    case 'PortTest':
      return <PortTestPage />;
    case 'Base64Tool':
      return <Base64ToolPage />;
    case 'SubnetCalc':
      return <SubnetCalcPage />;
    case 'WebSocketTest':
      return <WebSocketTestPage />;
    case 'WebSocketSSHTest':
      return <WebSocketSSHTestPage />;
    default:
      return (
        <view className="page">
          <view className="page-header">
            <text className="page-title">{route.name}</text>
          </view>
          <view className="empty-state">
            <text className="empty-state-text">该页面尚未迁移到 Lynx UI</text>
          </view>
        </view>
      );
  }
}

function ThemedRoot({ children }: { children: ReactNode }) {
  const [darkMode, setDarkMode] = useState<boolean>(false);
  useEffect(() => {
    KesshHost.getSettings()
      .then((settings) => setDarkMode(settings.darkMode))
      .catch(() => {
        /* host not bridged in dev preview */
      });
  }, []);
  return (
    <view className={clsx('app-root', darkMode ? 'lunaris-dark' : 'luna-light')}>
      {children}
    </view>
  );
}

export function App() {
  return (
    <ThemedRoot>
      <NavigatorProvider initial="Home">
        <CurrentRoute />
      </NavigatorProvider>
    </ThemedRoot>
  );
}

export default App;
