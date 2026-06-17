import { Input } from '@lynx-js/lynx-ui';
import { useEffect, useRef, useState } from '@lynx-js/react';

import { PageHeader, PrimaryAction } from '../components/Page';
import { useNavigator } from '../navigation/Navigator';
import { KesshHost } from '../native/host';

export interface TerminalParams {
  recordId?: number;
  password?: string;
}

const POLL_INTERVAL_MS = 150;

export function TerminalPage({ params }: { params?: Record<string, unknown> }) {
  const navigator = useNavigator();
  const initial = (params ?? {}) as TerminalParams;
  const [lines, setLines] = useState<string[]>([`正在连接...`]);
  const [command, setCommand] = useState<string>('');
  const [sessionId, setSessionId] = useState<number>(-1);
  const disposedRef = useRef<boolean>(false);
  const openTokenRef = useRef<number>(0);

  function appendLine(line: string) {
    setLines((current) => [...current, line]);
  }

  useEffect(() => {
    disposedRef.current = false;
    const token = ++openTokenRef.current;
    let pollHandle: ReturnType<typeof setTimeout> | null = null;
    let keepaliveHandle: ReturnType<typeof setInterval> | null = null;
    let activeSession = -1;

    async function open() {
      try {
        if (typeof initial.recordId !== 'number') {
          appendLine('未找到连接信息');
          return;
        }
        const settings = await KesshHost.getSettings().catch(() => null);
        const id = await KesshHost.openSession({
          host: '',
          port: 0,
          username: '',
          password: initial.password ?? '',
          editingId: initial.recordId,
          isEditing: true
        });
        if (disposedRef.current || token !== openTokenRef.current) {
          if (id > 0) await KesshHost.closeSession(id).catch(() => undefined);
          return;
        }
        if (id <= 0) {
          appendLine('打开终端会话失败');
          return;
        }
        activeSession = id;
        setSessionId(id);
        appendLine('连接成功');

        const interval = settings?.session.keepaliveInterval ?? 60;
        if (interval > 0) {
          keepaliveHandle = setInterval(() => {
            KesshHost.sendKeepalive(id).catch(() => undefined);
          }, interval * 1000);
        }

        const poll = async () => {
          if (disposedRef.current || token !== openTokenRef.current || activeSession <= 0) return;
          try {
            const chunk = await KesshHost.termRead(activeSession);
            if (chunk && chunk.length > 0) {
              appendLine(chunk);
            }
          } catch {
            /* ignore transient read errors */
          } finally {
            pollHandle = setTimeout(poll, POLL_INTERVAL_MS);
          }
        };
        poll();
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        appendLine(`连接失败: ${message}`);
      }
    }

    open();

    return () => {
      disposedRef.current = true;
      if (pollHandle) clearTimeout(pollHandle);
      if (keepaliveHandle) clearInterval(keepaliveHandle);
      if (activeSession > 0) {
        KesshHost.closeSession(activeSession).catch(() => undefined);
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initial.recordId]);

  async function run() {
    if (!command) return;
    if (sessionId <= 0) {
      await KesshHost.showToast('SSH 连接未就绪').catch(() => undefined);
      return;
    }
    appendLine(`$ ${command}`);
    await KesshHost.termWrite(sessionId, `${command}\n`).catch(() => undefined);
    setCommand('');
  }

  return (
    <view className="page">
      <PageHeader title="终端" />

      <scroll-view className="terminal-output" scroll-y>
        {lines.map((line, index) => (
          <text key={`${index}`} className="terminal-line">{line}</text>
        ))}
      </scroll-view>

      <view className="action-bar">
        <view className="form-field" style={{ flex: 1 }}>
          <Input
            className="form-field-input"
            value={command}
            placeholder="输入命令"
            onInput={(value) => setCommand(value)}
            onConfirm={() => run()}
          />
        </view>
        <PrimaryAction label="执行" onTap={run} disabled={sessionId <= 0} />
      </view>
    </view>
  );
}
