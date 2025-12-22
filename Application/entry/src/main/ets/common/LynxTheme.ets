import { SettingsStore } from './Stores';

export interface LynxPalette {
  pageBackground: string;
  surface: string;
  card: string;
  primaryText: string;
  secondaryText: string;
  border: string;
  accent: string;
}

const lightPalette: LynxPalette = {
  pageBackground: '#F5F7FA',
  surface: '#FFFFFFFF',
  card: '#10E7F0F5',
  primaryText: '#0F1115',
  secondaryText: '#6B7280',
  border: '#11000000',
  accent: '#1E7DD6'
};

const darkPalette: LynxPalette = {
  pageBackground: '#0F1115',
  surface: '#141821',
  card: '#1F2633',
  primaryText: '#E8EDF5',
  secondaryText: '#A5B0C3',
  border: '#33FFFFFF',
  accent: '#4A8DFF'
};

export function getLynxPalette(isDarkMode?: boolean): LynxPalette {
  const darkModeEnabled = isDarkMode ?? SettingsStore.darkMode;
  return darkModeEnabled ? darkPalette : lightPalette;
}
