/**
 * Theme controller. Holds the dark-mode flag at the root and lets any page
 * toggle it without forcing a full app reload.
 *
 * In production the source of truth is the HarmonyOS settings store
 * (KesshHost.setDarkMode). Here we mirror it in React state so the Luna
 * body class swaps immediately on toggle.
 */

import { createContext, useCallback, useContext, useEffect, useState } from '@lynx-js/react';
import type { ReactNode } from '@lynx-js/react';

import { clsx } from 'clsx';
import { KesshHost } from '../native/host';

interface ThemeContextValue {
  darkMode: boolean;
  setDarkMode: (value: boolean) => void;
  toggle: () => void;
  themeClass: string;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [darkMode, setDark] = useState<boolean>(false);

  useEffect(() => {
    KesshHost.getSettings()
      .then((settings) => setDark(settings.darkMode))
      .catch(() => undefined);
  }, []);

  const setDarkMode = useCallback((value: boolean) => {
    setDark(value);
    KesshHost.setDarkMode(value).catch(() => undefined);
  }, []);

  const toggle = useCallback(() => {
    setDarkMode(!darkMode);
  }, [darkMode, setDarkMode]);

  const value: ThemeContextValue = {
    darkMode,
    setDarkMode,
    toggle,
    themeClass: clsx('app-root', darkMode ? 'lunaris-dark' : 'luna-light')
  };

  return (
    <ThemeContext.Provider value={value}>
      <view className={value.themeClass}>{children}</view>
    </ThemeContext.Provider>
  );
}

export function useTheme(): ThemeContextValue {
  const value = useContext(ThemeContext);
  if (!value) {
    throw new Error('useTheme must be used inside ThemeProvider');
  }
  return value;
}
