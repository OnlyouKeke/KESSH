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

export interface LynxContainerProps {
  style?: LynxStyle;
  space?: number;
  onClick?: () => void;
}

function applyStyle(component: CommonMethod<any>, style?: LynxStyle): CommonMethod<any> {
  if (!style) {
    return component;
  }
  if (style.width !== undefined) { component.width(style.width); }
  if (style.height !== undefined) { component.height(style.height); }
  if (style.padding !== undefined) { component.padding(style.padding as Padding); }
  if (style.margin !== undefined) { component.margin(style.margin as Margin); }
  if (style.backgroundColor !== undefined) { component.backgroundColor(style.backgroundColor); }
  if (style.borderRadius !== undefined) { component.borderRadius(style.borderRadius as any); }
  if (style.layoutWeight !== undefined) { component.layoutWeight(style.layoutWeight); }
  if (style.justifyContent !== undefined) { (component as FlexAlignStyle).justifyContent(style.justifyContent); }
  if (style.alignItems !== undefined) { (component as FlexAlignStyle).alignItems(style.alignItems); }
  if (style.opacity !== undefined) { component.opacity(style.opacity); }
  if (style.borderColor !== undefined) { component.borderColor(style.borderColor); }
  if (style.borderWidth !== undefined) { component.borderWidth(style.borderWidth); }
  return component;
}

@Builder
export function LynxColumn(props: LynxContainerProps = {}, content?: () => void) {
  const component = Column({ space: props.space ?? 0 }) {
    content && content();
  };
  applyStyle(component, props.style);
  if (props.onClick) { component.onClick(props.onClick); }
}

@Builder
export function LynxRow(props: LynxContainerProps = {}, content?: () => void) {
  const component = Row({ space: props.space ?? 0 }) {
    content && content();
  };
  applyStyle(component, props.style);
  if (props.onClick) { component.onClick(props.onClick); }
}

export interface LynxScrollProps extends LynxContainerProps {
  scrollBar?: BarState;
}

@Builder
export function LynxScroll(props: LynxScrollProps = {}, content?: () => void) {
  const component = Scroll() {
    content && content();
  };
  component.scrollBar(props.scrollBar ?? BarState.Off);
  applyStyle(component, props.style);
}

export interface LynxTextStyle extends LynxStyle {
  fontSize?: number | string;
  fontWeight?: FontWeight;
  fontColor?: ResourceColor;
  textAlign?: TextAlign;
  maxLines?: number;
  textOverflow?: TextOverflowOptions;
}

export interface LynxTextProps {
  content: string;
  style?: LynxTextStyle;
}

@Builder
export function LynxText(props: LynxTextProps) {
  const component = Text(props.content);
  if (props.style?.fontSize !== undefined) { component.fontSize(props.style.fontSize as any); }
  if (props.style?.fontWeight !== undefined) { component.fontWeight(props.style.fontWeight); }
  if (props.style?.fontColor !== undefined) { component.fontColor(props.style.fontColor); }
  if (props.style?.textAlign !== undefined) { component.textAlign(props.style.textAlign); }
  if (props.style?.maxLines !== undefined) { component.maxLines(props.style.maxLines); }
  if (props.style?.textOverflow !== undefined) { component.textOverflow(props.style.textOverflow); }
  applyStyle(component, props.style);
}

export interface LynxButtonStyle extends LynxStyle {
  fontColor?: ResourceColor;
  type?: ButtonType;
  textSize?: number | string;
}

export interface LynxButtonProps {
  label: string;
  style?: LynxButtonStyle;
  onClick?: () => void;
}

@Builder
export function LynxButton(props: LynxButtonProps) {
  const component = Button(props.label, { type: props.style?.type ?? ButtonType.Normal });
  if (props.style?.fontColor !== undefined) { component.fontColor(props.style.fontColor); }
  if (props.style?.textSize !== undefined) { component.fontSize(props.style.textSize as any); }
  applyStyle(component, props.style);
  if (props.onClick) { component.onClick(props.onClick); }
}

export interface LynxBlankProps { style?: LynxStyle; }

@Builder
export function LynxBlank(props: LynxBlankProps = {}) {
  const component = Blank();
  applyStyle(component, props.style);
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
  const component = TextInput({ placeholder: props.placeholder, text: props.text });
  component.type(props.type ?? InputType.Normal);
  if (props.onChange) { component.onChange(props.onChange); }
  applyStyle(component, props.style);
}

@Builder
export function LynxTextArea(props: LynxInputProps) {
  const component = TextArea({ placeholder: props.placeholder, text: props.text });
  if (props.onChange) { component.onChange(props.onChange); }
  applyStyle(component, props.style);
}

export interface LynxToggleProps {
  isOn: boolean;
  type?: ToggleType;
  style?: LynxStyle;
  onChange?: (value: boolean) => void;
}

@Builder
export function LynxToggle(props: LynxToggleProps) {
  const component = Toggle({ isOn: props.isOn, type: props.type ?? ToggleType.Switch });
  if (props.onChange) { component.onChange(props.onChange); }
  applyStyle(component, props.style);
}

export interface LynxTabItem {
  title: string;
  builder: () => void;
}

export interface LynxTabsProps {
  index: number;
  items: Array<LynxTabItem>;
  style?: LynxStyle;
  barMode?: BarMode;
  barPosition?: BarPosition;
  onChange?: (index: number) => void;
}

@Builder
export function LynxTabs(props: LynxTabsProps) {
  const component = Tabs({ index: props.index }) {
    ForEach(props.items, (item: LynxTabItem, idx: number) => {
      TabContent() { item.builder(); }
        .tabBar({ text: item.title });
    }, (item: LynxTabItem, idx: number) => idx.toString());
  };
  component.barMode(props.barMode ?? BarMode.Fixed);
  component.barPosition(props.barPosition ?? BarPosition.End);
  if (props.onChange) { component.onChange(props.onChange); }
  applyStyle(component, props.style);
}

export interface LynxListProps {
  style?: LynxStyle;
  divider?: ListDividerOptions;
  edgeEffect?: EdgeEffect;
}

@Builder
export function LynxList(props: LynxListProps = {}, content?: () => void) {
  const component = List() { content && content(); };
  if (props.divider) { component.divider(props.divider); }
  if (props.edgeEffect !== undefined) { component.edgeEffect(props.edgeEffect); }
  applyStyle(component, props.style);
}

export interface LynxListItemProps extends LynxContainerProps {}

@Builder
export function LynxListItem(props: LynxListItemProps = {}, content?: () => void) {
  const component = ListItem() { content && content(); };
  applyStyle(component, props.style);
  if (props.onClick) { component.onClick(props.onClick); }
}

export interface LynxFlexProps extends LynxContainerProps { align?: Alignment; }

@Builder
export function LynxFlex(props: LynxFlexProps = {}, content?: () => void) {
  const component = Flex({ alignItems: props.style?.alignItems, justifyContent: props.style?.justifyContent }) {
    content && content();
  };
  applyStyle(component, props.style);
  if (props.onClick) { component.onClick(props.onClick); }
}
