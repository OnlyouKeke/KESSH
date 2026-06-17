import { Button } from '@lynx-js/lynx-ui';
import { clsx } from 'clsx';
import type { ReactNode } from '@lynx-js/react';

import { useNavigator } from '../navigation/Navigator';

/**
 * Reusable page shell with a back button, title and an optional trailing
 * action area. Mirrors the LynxRow header that every HarmonyOS ArkTS page
 * draws by hand.
 */
export interface PageHeaderProps {
  title: string;
  showBack?: boolean;
  trailing?: ReactNode;
}

export function PageHeader(props: PageHeaderProps) {
  const navigator = useNavigator();
  return (
    <view className="page-header">
      {props.showBack !== false && navigator.stack.length > 1 ? (
        <Button onClick={() => navigator.back()} className="btn-ghost" style={{ width: 40, marginRight: 8 }}>
          <text className="btn-ghost-text">{'<'}</text>
        </Button>
      ) : null}
      <text className="page-title">{props.title}</text>
      <view style={{ flex: 1 }} />
      {props.trailing}
    </view>
  );
}

export interface CardProps {
  className?: string;
  onTap?: () => void;
  children?: ReactNode;
}

export function Card(props: CardProps) {
  if (props.onTap) {
    return (
      <Button onClick={props.onTap} className={clsx('card card-tappable', props.className)}>
        {props.children}
      </Button>
    );
  }
  return <view className={clsx('card', props.className)}>{props.children}</view>;
}

export function EmptyState({ title, action }: { title: string; action?: ReactNode }) {
  return (
    <view className="empty-state">
      <text className="empty-state-text">{title}</text>
      {action}
    </view>
  );
}

export interface SectionTitleProps {
  children: ReactNode;
}

export function SectionTitle(props: SectionTitleProps) {
  return <text className="section-title">{props.children}</text>;
}

export interface PrimaryActionProps {
  label: string;
  onTap: () => void;
  disabled?: boolean;
}

export function PrimaryAction(props: PrimaryActionProps) {
  return (
    <Button onClick={props.onTap} disabled={props.disabled} className="btn-primary">
      <text className="btn-primary-text">{props.label}</text>
    </Button>
  );
}
