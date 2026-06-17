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

import './styles/theme.css';

const TABS: { key: 'history' | 'connect' | 'settings'; label: string }[] = [
  { key: 'history', label: '资产' },
  { key: 'connect', label: '连接' },
  { key: 'settings', label: '设置' }
];

function ConnectTab() {
  const navigator = useNavigator();
  return (
    <view className="page">
      <view className="page-header">
        <text className="page-title">连接</text>
      </view>
      <view style={{ padding: 16, gap: 12 }}>
        <view
          className="card card-tappable"
          bindtap={() => navigator.push('AddHost')}
        >
          <view className="card-row">
            <view style={{ flex: 1 }}>
              <text className="card-title">添加主机</text>
              <text className="card-subtitle">通过 SSH 连接到远程机器</text>
            </view>
            <text className="card-subtitle">{'>'}</text>
          </view>
        </view>
        <view
          className="card card-tappable"
          bindtap={() => navigator.push('SFTPPage')}
        >
          <view className="card-row">
            <view style={{ flex: 1 }}>
              <text className="card-title">SFTP 连接</text>
              <text className="card-subtitle">通过 SSH 安全传输文件</text>
            </view>
            <text className="card-subtitle">{'>'}</text>
          </view>
        </view>
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
    case 'Terminal':
      return <TerminalPage params={route.params} />;
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
