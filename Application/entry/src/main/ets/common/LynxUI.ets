import { ScrollDirection } from '@kit.ArkUI';

export interface LynxStyle {
  width?: string | number;
  height?: string | number;
  padding?: Padding | number | string;
  margin?: Margin | number | string;
  backgroundColor?: ResourceColor;
  borderRadius?: number | string;
  layoutWeight?: number;
  justifyContent?: FlexAlign;
  alignItems?: HorizontalAlign;
  opacity?: number;
  borderColor?: ResourceColor;
  borderWidth?: number;
}

function applyCommonStyle<T extends CommonMethod<any>>(component: T, style?: LynxStyle): T {
  if (!style) { return component; }
  if (style.width !== undefined) { component.width(style.width); }
  if (style.height !== undefined) { component.height(style.height); }
  if (style.padding !== undefined) { component.padding(style.padding as any); }
  if (style.margin !== undefined) { component.margin(style.margin as any); }
  if (style.backgroundColor !== undefined) { component.backgroundColor(style.backgroundColor); }
  if (style.borderRadius !== undefined) { component.borderRadius(style.borderRadius as any); }
  if (style.layoutWeight !== undefined) { component.layoutWeight(style.layoutWeight); }
  if (style.justifyContent !== undefined && (component as any).justifyContent) { (component as any).justifyContent(style.justifyContent); }
  if (style.alignItems !== undefined && (component as any).alignItems) { (component as any).alignItems(style.alignItems); }
  if (style.opacity !== undefined && (component as any).opacity) { (component as any).opacity(style.opacity); }
  if (style.borderColor !== undefined && (component as any).borderColor) { (component as any).borderColor(style.borderColor); }
  if (style.borderWidth !== undefined && (component as any).borderWidth) { (component as any).borderWidth(style.borderWidth); }
  return component;
}

export interface LynxContainerProps {
  style?: LynxStyle;
  space?: number;
  onClick?: () => void;
}

@Builder
export function LynxColumn(props: LynxContainerProps = {}, content?: () => void) {
  let view = Column({ space: props.space ?? 0 }) {
    content && content();
  };
  applyCommonStyle(view, props.style);
  if (props.onClick) { view.onClick(props.onClick); }
}

@Builder
export function LynxRow(props: LynxContainerProps = {}, content?: () => void) {
  let view = Row({ space: props.space ?? 0 }) {
    content && content();
  };
  applyCommonStyle(view, props.style);
  if (props.onClick) { view.onClick(props.onClick); }
}

export interface LynxScrollProps extends LynxContainerProps {
  scrollBar?: BarState;
  direction?: ScrollDirection;
}

@Builder
export function LynxScroll(props: LynxScrollProps = {}, content?: () => void) {
  let view = Scroll({ direction: props.direction ?? ScrollDirection.Vertical }) {
    content && content();
  };
  view.scrollBar(props.scrollBar ?? BarState.Off);
  applyCommonStyle(view, props.style);
}

export interface LynxTextProps {
  content: string;
  style?: LynxStyle & { fontSize?: number | string; fontWeight?: FontWeight; fontColor?: ResourceColor; textAlign?: TextAlign; maxLines?: number; textOverflow?: TextOverflow; }; 
}

@Builder
export function LynxText(props: LynxTextProps) {
  let view = Text(props.content);
  if (props.style?.fontSize !== undefined) { view.fontSize(props.style.fontSize as any); }
  if (props.style?.fontWeight !== undefined) { view.fontWeight(props.style.fontWeight); }
  if (props.style?.fontColor !== undefined) { view.fontColor(props.style.fontColor); }
  if (props.style?.textAlign !== undefined) { view.textAlign(props.style.textAlign); }
  if (props.style?.maxLines !== undefined) { view.maxLines(props.style.maxLines); }
  if (props.style?.textOverflow !== undefined) { view.textOverflow(props.style.textOverflow); }
  applyCommonStyle(view, props.style);
}

export interface LynxButtonProps {
  label: string;
  style?: LynxStyle & { fontColor?: ResourceColor; type?: ButtonType; textSize?: number | string; };
  onClick?: () => void;
}

@Builder
export function LynxButton(props: LynxButtonProps) {
  let view = Button(props.label, { type: props.style?.type ?? ButtonType.Normal });
  if (props.style?.fontColor !== undefined) { view.fontColor(props.style.fontColor); }
  if (props.style?.textSize !== undefined) { view.fontSize(props.style.textSize as any); }
  applyCommonStyle(view, props.style);
  if (props.onClick) { view.onClick(props.onClick); }
}

export interface LynxBlankProps { style?: LynxStyle; }

@Builder
export function LynxBlank(props: LynxBlankProps = {}) {
  let view = Blank();
  applyCommonStyle(view, props.style);
}

export interface LynxInputProps {
  placeholder?: string;
  text?: string;
  type?: InputType;
  style?: LynxStyle;
  onChange?: (value: string) => void;
}

@Builder
export function LynxTextInput(props: LynxInputProps) {
  let view = TextInput({ placeholder: props.placeholder, text: props.text });
  view.type(props.type ?? InputType.Normal);
  if (props.onChange) { view.onChange(props.onChange); }
  applyCommonStyle(view, props.style);
}

@Builder
export function LynxTextArea(props: LynxInputProps) {
  let view = TextArea({ placeholder: props.placeholder, text: props.text });
  if (props.onChange) { view.onChange(props.onChange); }
  applyCommonStyle(view, props.style);
}

export interface LynxToggleProps {
  isOn: boolean;
  type?: ToggleType;
  style?: LynxStyle;
  onChange?: (value: boolean) => void;
}

@Builder
export function LynxToggle(props: LynxToggleProps) {
  let view = Toggle({ isOn: props.isOn, type: props.type ?? ToggleType.Switch });
  if (props.onChange) { view.onChange(props.onChange); }
  applyCommonStyle(view, props.style);
}

export interface LynxTabsProps {
  index: number;
  items: Array<{ title: string; builder: () => void }>;
  style?: LynxStyle;
  barMode?: BarMode;
  barPosition?: BarPosition;
  onChange?: (index: number) => void;
}

@Builder
export function LynxTabs(props: LynxTabsProps) {
  let view = Tabs({ index: props.index }) {
    ForEach(props.items, (item, idx: number) => {
      TabContent() { item.builder(); }
        .tabBar({ text: item.title });
    }, (item, idx: number) => idx.toString());
  };
  view.barMode(props.barMode ?? BarMode.Fixed);
  view.barPosition(props.barPosition ?? BarPosition.End);
  if (props.onChange) { view.onChange(props.onChange); }
  applyCommonStyle(view, props.style);
}

export interface LynxListProps {
  style?: LynxStyle;
  divider?: { strokeWidth?: number; color?: ResourceColor };
  edgeEffect?: EdgeEffect;
}

@Builder
export function LynxList(props: LynxListProps = {}, content?: () => void) {
  let view = List() { content && content(); };
  if (props.divider) { view.divider(props.divider); }
  if (props.edgeEffect !== undefined) { view.edgeEffect(props.edgeEffect); }
  applyCommonStyle(view, props.style);
}

export interface LynxListItemProps extends LynxContainerProps {}

@Builder
export function LynxListItem(props: LynxListItemProps = {}, content?: () => void) {
  let view = ListItem() { content && content(); };
  applyCommonStyle(view, props.style);
  if (props.onClick) { view.onClick(props.onClick); }
}

export interface LynxFlexProps extends LynxContainerProps { align?: Alignment; }

@Builder
export function LynxFlex(props: LynxFlexProps = {}, content?: () => void) {
  let view = Flex({ alignItems: props.style?.alignItems, justifyContent: props.style?.justifyContent }) {
    content && content();
  };
  applyCommonStyle(view, props.style);
  if (props.onClick) { view.onClick(props.onClick); }
}
