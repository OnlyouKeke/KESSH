import { KeyboardAwareResponder, KeyboardAwareRoot } from '@lynx-js/lynx-ui';
import type { ReactNode } from '@lynx-js/react';

/**
 * Page shell that keeps text fields visible above the soft keyboard.
 *
 * Wraps children in lynx-ui's KeyboardAwareRoot + KeyboardAwareResponder
 * (as ScrollView). Each Input/TextArea inside should additionally be wrapped
 * in a KeyboardAwareTrigger; use <KeyboardField> below for that.
 *
 * This consolidates the KeyboardAwareInScrollView pattern from the lynx-ui
 * examples so every form page does not re-implement the wrapper tree.
 */
export function KeyboardAwarePage({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <KeyboardAwareRoot androidStatusBarPlusBottomBarHeight={0}>
      <KeyboardAwareResponder as="ScrollView" className={className ?? 'page'}>
        {children}
      </KeyboardAwareResponder>
    </KeyboardAwareRoot>
  );
}
