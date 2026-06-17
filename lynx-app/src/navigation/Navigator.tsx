/**
 * Tiny in-bundle navigation. ReactLynx does not ship a router by default, and
 * we do not want a heavyweight one for ~15 pages. This implementation maps the
 * existing HarmonyOS `router.pushUrl({ url: 'pages/X' })` calls 1-to-1 onto
 * a stack of route entries, so any page can call `navigate('Terminal')` and
 * the App shell renders the matching page.
 */

import { createContext, useCallback, useContext, useMemo, useState } from '@lynx-js/react';
import type { ReactNode } from '@lynx-js/react';

export type RouteName =
  | 'Home'
  | 'AddHost'
  | 'HostList'
  | 'HistoryPage'
  | 'Snippets'
  | 'SettingsPage'
  | 'SettingsKeys'
  | 'SettingsLogs'
  | 'SettingsSession'
  | 'SettingsTerminalFont'
  | 'Terminal'
  | 'SFTPPage'
  | 'Monitor'
  | 'SCPPage';

export interface RouteEntry {
  name: RouteName;
  params?: Record<string, unknown>;
}

interface NavigatorValue {
  stack: RouteEntry[];
  current: RouteEntry;
  push: (name: RouteName, params?: Record<string, unknown>) => void;
  replace: (name: RouteName, params?: Record<string, unknown>) => void;
  back: () => void;
  reset: (name: RouteName, params?: Record<string, unknown>) => void;
}

const NavigatorContext = createContext<NavigatorValue | null>(null);

export function NavigatorProvider({ children, initial = 'Home' }: { children: ReactNode; initial?: RouteName }) {
  const [stack, setStack] = useState<RouteEntry[]>([{ name: initial }]);

  const push = useCallback((name: RouteName, params?: Record<string, unknown>) => {
    setStack((previous) => [...previous, { name, params }]);
  }, []);

  const replace = useCallback((name: RouteName, params?: Record<string, unknown>) => {
    setStack((previous) => {
      const next = previous.slice(0, Math.max(0, previous.length - 1));
      next.push({ name, params });
      return next;
    });
  }, []);

  const back = useCallback(() => {
    setStack((previous) => (previous.length > 1 ? previous.slice(0, previous.length - 1) : previous));
  }, []);

  const reset = useCallback((name: RouteName, params?: Record<string, unknown>) => {
    setStack([{ name, params }]);
  }, []);

  const value = useMemo<NavigatorValue>(() => ({
    stack,
    current: stack[stack.length - 1],
    push,
    replace,
    back,
    reset
  }), [stack, push, replace, back, reset]);

  return <NavigatorContext.Provider value={value}>{children}</NavigatorContext.Provider>;
}

export function useNavigator(): NavigatorValue {
  const value = useContext(NavigatorContext);
  if (!value) {
    throw new Error('useNavigator must be used inside NavigatorProvider');
  }
  return value;
}
