import font from '@ohos.font';
import hilog from '@ohos.hilog';

const LOG_DOMAIN = 0xD15A;
const LOG_TAG = 'TerminalFonts';

export type TerminalFontKey = 'system' | 'source-code-pro' | 'jetbrains-mono' | 'google-sans-code';

export interface TerminalFontOption {
  key: TerminalFontKey;
  label: string;
  description: string;
  family: string;
}

const TERMINAL_FONT_OPTIONS: Array<TerminalFontOption> = [
  {
    key: 'system',
    label: '跟随系统',
    description: '使用系统默认的等宽字体',
    family: 'monospace'
  },
  {
    key: 'source-code-pro',
    label: 'Source Code Pro',
    description: 'Adobe 出品的经典等宽字体',
    family: 'SourceCodePro'
  },
  {
    key: 'jetbrains-mono',
    label: 'JetBrains Mono',
    description: 'JetBrains IDE 同款开发者字体',
    family: 'JetBrainsMono'
  },
  {
    key: 'google-sans-code',
    label: 'Google Sans Code',
    description: 'Google Sans 家族的等宽变体',
    family: 'GoogleSansCode'
  }
];

let fontsRegistered: boolean = false;

export function ensureTerminalFontsRegistered(): void {
  if (fontsRegistered) {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Fonts already registered, skipping');
    return;
  }
  
  hilog.info(LOG_DOMAIN, LOG_TAG, 'Starting font registration...');
  
  try {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Registering SourceCodePro...');
    font.registerFont({
      familyName: 'SourceCodePro',
      familySrc: $rawfile('fonts/SourceCodePro-Regular.ttf')
    });
    hilog.info(LOG_DOMAIN, LOG_TAG, 'SourceCodePro registered successfully');
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Registering JetBrainsMono...');
    font.registerFont({
      familyName: 'JetBrainsMono',
      familySrc: $rawfile('fonts/JetBrainsMono-Regular.ttf')
    });
    hilog.info(LOG_DOMAIN, LOG_TAG, 'JetBrainsMono registered successfully');
    
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Registering GoogleSansCode...');
    font.registerFont({
      familyName: 'GoogleSansCode',
      familySrc: $rawfile('fonts/GoogleSansCode-Regular.ttf')
    });
    hilog.info(LOG_DOMAIN, LOG_TAG, 'GoogleSansCode registered successfully');
    
    fontsRegistered = true;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'All terminal fonts registered successfully');
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    hilog.error(LOG_DOMAIN, LOG_TAG, 'Register font failed: %{public}s', message);
  }
}

export function getTerminalFontOptions(): Array<TerminalFontOption> {
  return TERMINAL_FONT_OPTIONS;
}

export function resolveFontFamily(key: TerminalFontKey): string {
  const option = TERMINAL_FONT_OPTIONS.find(item => item.key === key);
  return option ? option.family : 'monospace';
}
