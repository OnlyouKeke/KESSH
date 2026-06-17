import { Card, EmptyState, PageHeader, PrimaryAction } from '../components/Page';
import { useEffect, useRef, useState } from '@lynx-js/react';
import { Input } from '@lynx-js/lynx-ui';

import { useNavigator } from '../navigation/Navigator';
import { useConnections } from '../native/hooks';
import { KesshHost } from '../native/host';
import type { ConnectionRecord } from '../native/host';

interface FileItem {
  name: string;
  path: string;
  size: number;
  isDirectory: boolean;
  permissions: string;
}

function parseLs(output: string, currentPath: string): FileItem[] {
  const result: FileItem[] = [];
  for (const raw of output.split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('total')) continue;
    const parts = line.split(/\s+/);
    if (parts.length < 9) continue;
    const permissions = parts[0];
    const isDirectory = permissions.startsWith('d');
    const name = parts.slice(8).join(' ');
    if (name === '.' || name === '..') continue;
    const size = parseInt(parts[4], 10) || 0;
    const fullPath = currentPath === '/' ? `/${name}` : `${currentPath}/${name}`;
    result.push({ name, path: fullPath, size, isDirectory, permissions });
  }
  if (currentPath !== '/' && currentPath !== '~') {
    result.unshift({ name: '..', path: '..', size: 0, isDirectory: true, permissions: '' });
  }
  return result;
}

function formatSize(bytes: number): string {
  if (bytes === 0) return '-';
  if (bytes < 1024) return `${bytes}B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)}MB`;
  return `${(bytes / 1024 / 1024 / 1024).toFixed(1)}GB`;
}

export function SCPPage({ params }: { params?: Record<string, unknown> }) {
  const navigator = useNavigator();
  const initial = (params ?? {}) as { recordId?: number };
  const { data: hosts } = useConnections();
  const [path, setPath] = useState<string>('~');
  const [files, setFiles] = useState<FileItem[]>([]);
  const [connected, setConnected] = useState<boolean>(false);
  const [pathInput, setPathInput] = useState<string>('~');
  const sessionRef = useRef<number>(-1);
  const disposedRef = useRef<boolean>(false);

  useEffect(() => {
    if (typeof initial.recordId === 'number' && hosts) {
      const record = hosts.find((host) => host.id === initial.recordId);
      if (record) connect(record);
    }
    return () => {
      disposedRef.current = true;
      if (sessionRef.current > 0) KesshHost.closeSession(sessionRef.current).catch(() => undefined);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initial.recordId, hosts?.length]);

  async function connect(record: ConnectionRecord) {
    if (record.authType === 'key') {
      await KesshHost.showToast('密钥认证暂未支持').catch(() => undefined);
      return;
    }
    const hasPwd = await KesshHost.hasPassword(record.id).catch(() => false);
    if (!hasPwd) {
      navigator.replace('AddHost', { editingId: record.id, host: record.host, port: record.port, username: record.username });
      return;
    }
    try {
      const sid = await KesshHost.openSession({
        host: record.host,
        port: record.port,
        username: record.username,
        editingId: record.id,
        isEditing: true
      });
      if (disposedRef.current) {
        if (sid > 0) await KesshHost.closeSession(sid).catch(() => undefined);
        return;
      }
      if (sid <= 0) {
        await KesshHost.showToast('SSH 连接失败').catch(() => undefined);
        return;
      }
      sessionRef.current = sid;
      setConnected(true);
      await load('~');
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await KesshHost.showToast(`连接失败: ${message}`).catch(() => undefined);
    }
  }

  async function load(targetPath: string) {
    if (sessionRef.current <= 0) return;
    setPath(targetPath);
    setPathInput(targetPath);
    try {
      const output = await KesshHost.listFiles(sessionRef.current, targetPath);
      const parsed = parseLs(output, targetPath);
      setFiles(parsed);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await KesshHost.showToast(`加载文件失败: ${message}`).catch(() => undefined);
    }
  }

  function navigate(file: FileItem) {
    if (!file.isDirectory) return;
    if (file.name === '..') {
      const segments = path.split('/').filter(Boolean);
      segments.pop();
      load(segments.length === 0 ? '/' : `/${segments.join('/')}`);
    } else {
      load(file.path);
    }
  }

  async function downloadFile(file: FileItem) {
    if (file.isDirectory) {
      await KesshHost.showToast('暂不支持下载文件夹').catch(() => undefined);
      return;
    }
    try {
      const content = await KesshHost.downloadFile(sessionRef.current, file.path);
      await KesshHost.showToast(`已下载 ${file.name} (${formatSize(content.length)})`).catch(() => undefined);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await KesshHost.showToast(`下载失败: ${message}`).catch(() => undefined);
    }
  }

  return (
    <view className="page">
      <PageHeader title="SCP 文件传输" />

      {!connected ? (
        <view style={{ padding: 16, gap: 12 }}>
          <text className="card-subtitle">请选择主机以打开 SCP</text>
          {(hosts ?? []).length === 0 ? (
            <EmptyState title="无可用主机" />
          ) : (
            (hosts ?? []).map((record) => (
              <Card key={record.id} onTap={() => connect(record)}>
                <text className="card-title">{record.name}</text>
                <text className="card-subtitle">{record.host}:{record.port}</text>
              </Card>
            ))
          )}
        </view>
      ) : (
        <view style={{ flex: 1 }}>
          <view style={{ padding: 12, flexDirection: 'row', gap: 8, alignItems: 'center' }}>
            <view className="form-field" style={{ flex: 1 }}>
              <Input
                className="form-field-input"
                value={pathInput}
                onInput={(value) => setPathInput(value)}
                onConfirm={() => load(pathInput)}
              />
            </view>
            <PrimaryAction label="跳转" onTap={() => load(pathInput)} />
          </view>

          {files.length === 0 ? (
            <EmptyState title="空目录" />
          ) : (
            <scroll-view scroll-y style={{ flex: 1, padding: 16 }}>
              {files.map((file, index) => (
                <view key={`${index}-${file.path}`} className="card">
                  <view className="card-row">
                    <text style={{ fontSize: 20, marginRight: 12 }}>{file.isDirectory ? '📁' : '📄'}</text>
                    <view style={{ flex: 1 }} bindtap={() => navigate(file)}>
                      <text className="card-title">{file.name}</text>
                      {!file.isDirectory ? (
                        <text className="card-subtitle">{formatSize(file.size)}</text>
                      ) : null}
                    </view>
                    {!file.isDirectory && file.name !== '..' ? (
                      <view bindtap={() => downloadFile(file)} style={{ padding: 8, borderRadius: 8, backgroundColor: 'var(--primary)' }}>
                        <text style={{ color: 'var(--primary-content)', fontSize: 13 }}>下载</text>
                      </view>
                    ) : null}
                  </view>
                </view>
              ))}
            </scroll-view>
          )}
        </view>
      )}
    </view>
  );
}
