import { useEffect, useRef, useState } from '@lynx-js/react';

import { Card, EmptyState, PageHeader, PrimaryAction } from '../components/Page';
import { useNavigator } from '../navigation/Navigator';
import { useConnections } from '../native/hooks';
import { KesshHost } from '../native/host';
import type { ConnectionRecord } from '../native/host';

interface SFTPFile {
  name: string;
  isDir: boolean;
  size: string;
  permissions: string;
}

function parseLs(output: string): SFTPFile[] {
  const result: SFTPFile[] = [];
  for (const raw of output.split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('total')) continue;
    const parts = line.split(/\s+/);
    if (parts.length < 9) continue;
    const permissions = parts[0];
    const size = parts[4];
    const name = parts.slice(8).join(' ');
    if (name === '.' || name === '..') continue;
    result.push({ name, isDir: permissions.startsWith('d'), size, permissions });
  }
  return result;
}

export function SFTPPage() {
  const navigator = useNavigator();
  const { data: hosts } = useConnections();
  const [connecting, setConnecting] = useState<boolean>(false);
  const [connected, setConnected] = useState<boolean>(false);
  const [status, setStatus] = useState<string>('请选择主机进行连接');
  const [currentPath, setCurrentPath] = useState<string>('/');
  const [files, setFiles] = useState<SFTPFile[]>([]);
  const sessionRef = useRef<number>(-1);
  const tokenRef = useRef<number>(0);
  const disposedRef = useRef<boolean>(false);

  useEffect(() => {
    return () => {
      disposedRef.current = true;
      tokenRef.current++;
      if (sessionRef.current > 0) {
        KesshHost.closeSession(sessionRef.current).catch(() => undefined);
      }
    };
  }, []);

  async function listFiles(path: string) {
    if (sessionRef.current <= 0) return;
    setCurrentPath(path);
    try {
      const output = await KesshHost.listFiles(sessionRef.current, path);
      const parsed = parseLs(output).sort((a, b) => {
        if (a.isDir && !b.isDir) return -1;
        if (!a.isDir && b.isDir) return 1;
        return a.name.localeCompare(b.name);
      });
      const withParent = path !== '/' && path.length > 1
        ? [{ name: '..', isDir: true, size: '', permissions: '' } as SFTPFile, ...parsed]
        : parsed;
      setFiles(withParent);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setStatus(`列目录失败: ${message}`);
    }
  }

  async function connect(record: ConnectionRecord) {
    if (connecting || connected) return;
    if (record.authType === 'key') {
      await KesshHost.showToast('密钥认证暂未支持').catch(() => undefined);
      return;
    }
    const hasPwd = await KesshHost.hasPassword(record.id).catch(() => false);
    if (!hasPwd) {
      await KesshHost.showToast('请输入密码后连接').catch(() => undefined);
      navigator.push('AddHost', { editingId: record.id, host: record.host, port: record.port, username: record.username });
      return;
    }
    const token = ++tokenRef.current;
    setConnecting(true);
    setStatus(`正在连接 ${record.host}…`);
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
        setStatus('连接失败');
        return;
      }
      sessionRef.current = sid;
      setConnected(true);
      setStatus('已连接');
      await listFiles('/');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      setStatus(`连接失败: ${message}`);
    } finally {
      setConnecting(false);
    }
  }

  function navigate(file: SFTPFile) {
    if (!file.isDir) return;
    let next = '';
    if (file.name === '..') {
      const segments = currentPath.split('/').filter(Boolean);
      segments.pop();
      next = segments.length > 0 ? '/' + segments.join('/') : '/';
    } else {
      next = currentPath.endsWith('/') ? `${currentPath}${file.name}` : `${currentPath}/${file.name}`;
    }
    listFiles(next);
  }

  return (
    <view className="page">
      <PageHeader title="SFTP 文件" />
      {!connected ? (
        <view style={{ padding: 16, gap: 12 }}>
          <text className="card-subtitle">{status}</text>
          {(hosts ?? []).length === 0 ? (
            <EmptyState title="无可用主机，请先添加主机" />
          ) : (
            (hosts ?? []).map((record) => (
              <Card key={record.id} onTap={() => connect(record)}>
                <view className="card-row">
                  <view style={{ flex: 1 }}>
                    <text className="card-title">{record.name}</text>
                    <text className="card-subtitle">{record.host}</text>
                  </view>
                  <text className="card-subtitle" style={{ color: 'var(--primary)' }}>{connecting ? '连接中' : '选择'}</text>
                </view>
              </Card>
            ))
          )}
        </view>
      ) : (
        <view style={{ flex: 1 }}>
          <text className="card-subtitle" style={{ padding: '8px 16px' }}>路径: {currentPath}</text>
          <scroll-view scroll-y style={{ flex: 1, padding: 16 }}>
            {files.map((file, index) => (
              <view
                key={`${index}-${file.name}`}
                className="card card-tappable"
                bindtap={() => navigate(file)}
              >
                <view className="card-row">
                  <text style={{ fontSize: 20, marginRight: 12 }}>{file.isDir ? '📁' : '📄'}</text>
                  <view style={{ flex: 1 }}>
                    <text className="card-title">{file.name}</text>
                    {file.name !== '..' ? (
                      <text className="card-subtitle">{file.permissions} · {file.size}</text>
                    ) : null}
                  </view>
                  {file.isDir ? <text className="card-subtitle">{'>'}</text> : null}
                </view>
              </view>
            ))}
          </scroll-view>
        </view>
      )}
    </view>
  );
}
