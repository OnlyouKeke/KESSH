import { useState } from '@lynx-js/react';
import { Input, KeyboardAwareTrigger } from '@lynx-js/lynx-ui';

import { Card, EmptyState, PageHeader, PrimaryAction } from '../components/Page';
import { KeyboardAwarePage } from '../components/KeyboardAwarePage';
import { useSnippets } from '../native/hooks';
import { KesshHost } from '../native/host';

export function SnippetsPage() {
  const { data, loading, error, reload } = useSnippets();
  const [title, setTitle] = useState<string>('');
  const [command, setCommand] = useState<string>('');

  async function add() {
    if (!title.trim() || !command.trim()) return;
    try {
      await KesshHost.addSnippet(title.trim(), command.trim());
      setTitle('');
      setCommand('');
      reload();
      await KesshHost.showToast('已添加').catch(() => undefined);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      await KesshHost.showToast(`保存失败: ${message}`).catch(() => undefined);
    }
  }

  async function remove(id: number) {
    await KesshHost.removeSnippet(id).catch(() => undefined);
    reload();
  }

  return (
    <KeyboardAwarePage>
      <PageHeader title="代码片段" />

      <view style={{ padding: 16, gap: 12 }}>
        <KeyboardAwareTrigger>
          <view className="form-field">
            <text className="form-field-label">标题</text>
            <Input className="form-field-input" value={title} onInput={(value) => setTitle(value)} />
          </view>
        </KeyboardAwareTrigger>
        <KeyboardAwareTrigger>
          <view className="form-field">
            <text className="form-field-label">命令</text>
            <Input className="form-field-input" value={command} onInput={(value) => setCommand(value)} />
          </view>
        </KeyboardAwareTrigger>
        <PrimaryAction label="添加片段" onTap={add} />
      </view>

      {loading ? (
        <EmptyState title="加载中..." />
      ) : error ? (
        <EmptyState title={`数据源不可用 (${error.message})`} />
      ) : (data ?? []).length === 0 ? (
        <EmptyState title="暂无片段" />
      ) : (
        <view style={{ padding: 16, gap: 12 }}>
          {(data ?? []).map((snippet) => (
            <Card key={snippet.id} onTap={() => remove(snippet.id)}>
              <text className="card-title">{snippet.title}</text>
              <text className="snippet-code">{snippet.command}</text>
              <text className="card-subtitle">点击删除</text>
            </Card>
          ))}
        </view>
      )}
    </KeyboardAwarePage>
  );
}
