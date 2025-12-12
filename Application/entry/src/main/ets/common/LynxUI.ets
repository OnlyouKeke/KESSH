export interface LynxStyle {
  width?: string | number;
  height?: string | number;
  padding?: Padding | number | string;
  margin?: Margin | number | string;
  backgroundColor?: ResourceColor;
  borderRadius?: number | string;
  layoutWeight?: number;
  justifyContent?: HorizontalAlign | VerticalAlign | FlexAlign;
  alignItems?: HorizontalAlign | VerticalAlign | ItemAlign;
  opacity?: number;
  borderColor?: ResourceColor;
  borderWidth?: number;
}

export interface LynxContainerProps {
  style?: LynxStyle;
  space?: number;
  onClick?: () => void;
}

@Builder
export function LynxColumn(props: LynxContainerProps = {}, content?: () => void) {
  Column({ space: props.space ?? 0 }) {
    if (content) { content(); }
  }
  .width(props.style?.width)
  .height(props.style?.height)
  .padding(props.style?.padding as Padding)
  .margin(props.style?.margin as Margin)
  .backgroundColor(props.style?.backgroundColor)
  .borderRadius(props.style?.borderRadius as number)
  .layoutWeight(props.style?.layoutWeight)
  .justifyContent(props.style?.justifyContent as VerticalAlign)
  .alignItems(props.style?.alignItems as HorizontalAlign)
  .opacity(props.style?.opacity)
  .borderColor(props.style?.borderColor)
  .borderWidth(props.style?.borderWidth)
  .onClick(props.onClick ?? undefined);
}

@Builder
export function LynxRow(props: LynxContainerProps = {}, content?: () => void) {
  Row({ space: props.space ?? 0 }) {
    if (content) { content(); }
  }
  .width(props.style?.width)
  .height(props.style?.height)
  .padding(props.style?.padding as Padding)
  .margin(props.style?.margin as Margin)
  .backgroundColor(props.style?.backgroundColor)
  .borderRadius(props.style?.borderRadius as number)
  .layoutWeight(props.style?.layoutWeight)
  .justifyContent(props.style?.justifyContent as HorizontalAlign)
  .alignItems(props.style?.alignItems as VerticalAlign)
  .opacity(props.style?.opacity)
  .borderColor(props.style?.borderColor)
  .borderWidth(props.style?.borderWidth)
  .onClick(props.onClick ?? undefined);
}

export interface LynxScrollProps extends LynxContainerProps {
  scrollBar?: BarState;
}

@Builder
export function LynxScroll(props: LynxScrollProps = {}, content?: () => void) {
  Scroll() {
    if (content) { content(); }
  }
  .scrollBar(props.scrollBar ?? BarState.Off)
  .width(props.style?.width)
  .height(props.style?.height)
  .padding(props.style?.padding as Padding)
  .margin(props.style?.margin as Margin)
  .backgroundColor(props.style?.backgroundColor)
  .borderRadius(props.style?.borderRadius as number)
  .layoutWeight(props.style?.layoutWeight)
  .opacity(props.style?.opacity)
  .borderColor(props.style?.borderColor)
  .borderWidth(props.style?.borderWidth)
  .onClick(props.onClick ?? undefined);
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
  Text(props.content)
    .fontSize(props.style?.fontSize)
    .fontWeight(props.style?.fontWeight)
    .fontColor(props.style?.fontColor)
    .textAlign(props.style?.textAlign)
    .maxLines(props.style?.maxLines)
    .textOverflow(props.style?.textOverflow)
    .width(props.style?.width)
    .height(props.style?.height)
    .padding(props.style?.padding as Padding)
    .margin(props.style?.margin as Margin)
    .backgroundColor(props.style?.backgroundColor)
    .borderRadius(props.style?.borderRadius as number)
    .layoutWeight(props.style?.layoutWeight)
    .opacity(props.style?.opacity)
    .borderColor(props.style?.borderColor)
    .borderWidth(props.style?.borderWidth);
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
  Button(props.label, { type: props.style?.type ?? ButtonType.Normal })
    .fontColor(props.style?.fontColor)
    .fontSize(props.style?.textSize)
    .width(props.style?.width)
    .height(props.style?.height)
    .padding(props.style?.padding as Padding)
    .margin(props.style?.margin as Margin)
    .backgroundColor(props.style?.backgroundColor)
    .borderRadius(props.style?.borderRadius as number)
    .layoutWeight(props.style?.layoutWeight)
    .opacity(props.style?.opacity)
    .borderColor(props.style?.borderColor)
    .borderWidth(props.style?.borderWidth)
    .onClick(props.onClick ?? undefined);
}

export interface LynxBlankProps { style?: LynxStyle; onClick?: () => void; }

@Builder
export function LynxBlank(props: LynxBlankProps = {}) {
  Blank()
    .width(props.style?.width)
    .height(props.style?.height)
    .padding(props.style?.padding as Padding)
    .margin(props.style?.margin as Margin)
    .backgroundColor(props.style?.backgroundColor)
    .borderRadius(props.style?.borderRadius as number)
    .layoutWeight(props.style?.layoutWeight)
    .opacity(props.style?.opacity)
    .borderColor(props.style?.borderColor)
    .borderWidth(props.style?.borderWidth)
    .onClick(props.onClick ?? undefined);
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
  TextInput({ placeholder: props.placeholder, text: props.text })
    .type(props.type ?? InputType.Normal)
    .onChange(props.onChange ?? undefined)
    .width(props.style?.width)
    .height(props.style?.height)
    .padding(props.style?.padding as Padding)
    .margin(props.style?.margin as Margin)
    .backgroundColor(props.style?.backgroundColor)
    .borderRadius(props.style?.borderRadius as number)
    .layoutWeight(props.style?.layoutWeight)
    .opacity(props.style?.opacity)
    .borderColor(props.style?.borderColor)
    .borderWidth(props.style?.borderWidth);
}

@Builder
export function LynxTextArea(props: LynxInputProps) {
  TextArea({ placeholder: props.placeholder, text: props.text })
    .onChange(props.onChange ?? undefined)
    .width(props.style?.width)
    .height(props.style?.height)
    .padding(props.style?.padding as Padding)
    .margin(props.style?.margin as Margin)
    .backgroundColor(props.style?.backgroundColor)
    .borderRadius(props.style?.borderRadius as number)
    .layoutWeight(props.style?.layoutWeight)
    .opacity(props.style?.opacity)
    .borderColor(props.style?.borderColor)
    .borderWidth(props.style?.borderWidth);
}

export interface LynxToggleProps {
  isOn: boolean;
  type?: ToggleType;
  style?: LynxStyle;
  onChange?: (value: boolean) => void;
}

@Builder
export function LynxToggle(props: LynxToggleProps) {
  Toggle({ isOn: props.isOn, type: props.type ?? ToggleType.Switch })
    .onChange(props.onChange ?? undefined)
    .width(props.style?.width)
    .height(props.style?.height)
    .padding(props.style?.padding as Padding)
    .margin(props.style?.margin as Margin)
    .backgroundColor(props.style?.backgroundColor)
    .borderRadius(props.style?.borderRadius as number)
    .layoutWeight(props.style?.layoutWeight)
    .opacity(props.style?.opacity)
    .borderColor(props.style?.borderColor)
    .borderWidth(props.style?.borderWidth);
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
  Tabs({ index: props.index }) {
    ForEach(props.items, (item: LynxTabItem, idx: number) => {
      TabContent() { item.builder(); }
        .tabBar({ text: item.title });
    }, (item: LynxTabItem, idx: number) => idx.toString());
  }
  .barMode(props.barMode ?? BarMode.Fixed)
  .barPosition(props.barPosition ?? BarPosition.End)
  .onChange(props.onChange ?? undefined)
  .width(props.style?.width)
  .height(props.style?.height)
  .padding(props.style?.padding as Padding)
  .margin(props.style?.margin as Margin)
  .backgroundColor(props.style?.backgroundColor)
  .borderRadius(props.style?.borderRadius as number)
  .layoutWeight(props.style?.layoutWeight)
  .opacity(props.style?.opacity)
  .borderColor(props.style?.borderColor)
  .borderWidth(props.style?.borderWidth);
}

export interface LynxListProps {
  style?: LynxStyle;
  divider?: ListDividerOptions;
  edgeEffect?: EdgeEffect;
  onClick?: () => void;
}

@Builder
export function LynxList(props: LynxListProps = {}, content?: () => void) {
  List() { if (content) { content(); } }
    .divider(props.divider)
    .edgeEffect(props.edgeEffect)
    .width(props.style?.width)
    .height(props.style?.height)
    .padding(props.style?.padding as Padding)
    .margin(props.style?.margin as Margin)
    .backgroundColor(props.style?.backgroundColor)
    .borderRadius(props.style?.borderRadius as number)
    .layoutWeight(props.style?.layoutWeight)
    .opacity(props.style?.opacity)
    .borderColor(props.style?.borderColor)
    .borderWidth(props.style?.borderWidth)
    .onClick(props.onClick ?? undefined);
}

export interface LynxListItemProps extends LynxContainerProps {}

@Builder
export function LynxListItem(props: LynxListItemProps = {}, content?: () => void) {
  ListItem() { if (content) { content(); } }
    .width(props.style?.width)
    .height(props.style?.height)
    .padding(props.style?.padding as Padding)
    .margin(props.style?.margin as Margin)
    .backgroundColor(props.style?.backgroundColor)
    .borderRadius(props.style?.borderRadius as number)
    .layoutWeight(props.style?.layoutWeight)
    .opacity(props.style?.opacity)
    .borderColor(props.style?.borderColor)
    .borderWidth(props.style?.borderWidth)
    .onClick(props.onClick ?? undefined);
}

export interface LynxFlexProps extends LynxContainerProps { align?: Alignment; }

@Builder
export function LynxFlex(props: LynxFlexProps = {}, content?: () => void) {
  Flex({ alignItems: props.style?.alignItems as ItemAlign, justifyContent: props.style?.justifyContent as FlexAlign }) {
    if (content) { content(); }
  }
  .width(props.style?.width)
  .height(props.style?.height)
  .padding(props.style?.padding as Padding)
  .margin(props.style?.margin as Margin)
  .backgroundColor(props.style?.backgroundColor)
  .borderRadius(props.style?.borderRadius as number)
  .layoutWeight(props.style?.layoutWeight)
  .opacity(props.style?.opacity)
  .borderColor(props.style?.borderColor)
  .borderWidth(props.style?.borderWidth)
  .onClick(props.onClick ?? undefined);
}
