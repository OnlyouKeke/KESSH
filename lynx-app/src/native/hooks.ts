import { useCallback, useEffect, useState } from '@lynx-js/react';

import { KesshHost } from './host';
import type {
  AppSettings,
  ConnectionRecord,
  FontOption,
  ImportedKey,
  Snippet
} from './host';

interface AsyncResult<T> {
  data: T | null;
  loading: boolean;
  error: Error | null;
  reload: () => void;
}

function useAsync<T>(loader: () => Promise<T>, deps: unknown[] = []): AsyncResult<T> {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<Error | null>(null);
  const [token, setToken] = useState<number>(0);

  const reload = useCallback(() => setToken((value) => value + 1), []);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    loader()
      .then((value) => {
        if (cancelled) return;
        setData(value);
        setError(null);
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setError(err instanceof Error ? err : new Error(String(err)));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, ...deps]);

  return { data, loading, error, reload };
}

export function useSettings(): AsyncResult<AppSettings> {
  return useAsync(() => KesshHost.getSettings());
}

export function useConnections(): AsyncResult<ConnectionRecord[]> {
  return useAsync(() => KesshHost.listConnections());
}

export function useSnippets(): AsyncResult<Snippet[]> {
  return useAsync(() => KesshHost.listSnippets());
}

export function useKeys(): AsyncResult<ImportedKey[]> {
  return useAsync(() => KesshHost.listKeys());
}

export function useLogs(): AsyncResult<string[]> {
  return useAsync(() => KesshHost.listLogs());
}

export function useFontOptions(): AsyncResult<FontOption[]> {
  return useAsync(() => KesshHost.listFontOptions());
}
