export interface LynxStyle {
  width?: string | number;
  height?: string | number;
  padding?: Padding | number | string;
  margin?: Margin | number | string;
  backgroundColor?: ResourceColor;
  borderRadius?: number | string;
  layoutWeight?: number;
  justifyContent?: FlexAlign;
  alignItems?: ItemAlign;
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
  const style = props.style;
  Column({ space: props.space ?? 0 }) {
    content && content();
  }
  .width(style?.width)
  .height(style?.height)
  .padding(style?.padding as Padding)
  .margin(style?.margin as Margin)
  .backgroundColor(style?.backgroundColor)
  .borderRadius(style?.borderRadius as number)
  .layoutWeight(style?.layoutWeight)
  .justifyContent(style?.justifyContent)
  .alignItems(style?.alignItems)
  .opacity(style?.opacity)
  .borderColor(style?.borderColor)
  .borderWidth(style?.borderWidth)
  .onClick(props.onClick ?? undefined);
}

@Builder
export function LynxRow(props: LynxContainerProps = {}, content?: () => void) {
  const style = props.style;
  Row({ space: props.space ?? 0 }) {
    content && content();
  }
  .width(style?.width)
  .height(style?.height)
  .padding(style?.padding as Padding)
  .margin(style?.margin as Margin)
  .backgroundColor(style?.backgroundColor)
  .borderRadius(style?.borderRadius as number)
  .layoutWeight(style?.layoutWeight)
  .justifyContent(style?.justifyContent)
  .alignItems(style?.alignItems)
  .opacity(style?.opacity)
  .borderColor(style?.borderColor)
  .borderWidth(style?.borderWidth)
  .onClick(props.onClick ?? undefined);
}

export interface LynxScrollProps extends LynxContainerProps {
  scrollBar?: BarState;
}

@Builder
export function LynxScroll(props: LynxScrollProps = {}, content?: () => void) {
  const style = props.style;
  Scroll() {
    content && content();
  }
  .scrollBar(props.scrollBar ?? BarState.Off)
  .width(style?.width)
  .height(style?.height)
  .padding(style?.padding as Padding)
  .margin(style?.margin as Margin)
  .backgroundColor(style?.backgroundColor)
  .borderRadius(style?.borderRadius as number)
  .layoutWeight(style?.layoutWeight)
  .justifyContent(style?.justifyContent)
  .alignItems(style?.alignItems)
  .opacity(style?.opacity)
  .borderColor(style?.borderColor)
  .borderWidth(style?.borderWidth)
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
  const style = props.style;
  Text(props.content)
    .fontSize(style?.fontSize)
    .fontWeight(style?.fontWeight)
    .fontColor(style?.fontColor)
    .textAlign(style?.textAlign)
    .maxLines(style?.maxLines)
    .textOverflow(style?.textOverflow)
    .width(style?.width)
    .height(style?.height)
    .padding(style?.padding as Padding)
    .margin(style?.margin as Margin)
    .backgroundColor(style?.backgroundColor)
    .borderRadius(style?.borderRadius as number)
    .layoutWeight(style?.layoutWeight)
    .justifyContent(style?.justifyContent)
    .alignItems(style?.alignItems)
    .opacity(style?.opacity)
    .borderColor(style?.borderColor)
    .borderWidth(style?.borderWidth);
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
  const style = props.style;
  Button(props.label, { type: style?.type ?? ButtonType.Normal })
    .fontColor(style?.fontColor)
    .fontSize(style?.textSize)
    .width(style?.width)
    .height(style?.height)
    .padding(style?.padding as Padding)
    .margin(style?.margin as Margin)
    .backgroundColor(style?.backgroundColor)
    .borderRadius(style?.borderRadius as number)
    .layoutWeight(style?.layoutWeight)
    .justifyContent(style?.justifyContent)
    .alignItems(style?.alignItems)
    .opacity(style?.opacity)
    .borderColor(style?.borderColor)
    .borderWidth(style?.borderWidth)
    .onClick(props.onClick ?? undefined);
}

export interface LynxBlankProps { style?: LynxStyle; }

@Builder
export function LynxBlank(props: LynxBlankProps = {}) {
  const style = props.style;
  Blank()
    .width(style?.width)
    .height(style?.height)
    .padding(style?.padding as Padding)
    .margin(style?.margin as Margin)
    .backgroundColor(style?.backgroundColor)
    .borderRadius(style?.borderRadius as number)
    .layoutWeight(style?.layoutWeight)
    .justifyContent(style?.justifyContent)
    .alignItems(style?.alignItems)
    .opacity(style?.opacity)
    .borderColor(style?.borderColor)
    .borderWidth(style?.borderWidth)
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
  const style = props.style;
  TextInput({ placeholder: props.placeholder, text: props.text })
    .type(props.type ?? InputType.Normal)
    .onChange(props.onChange ?? undefined)
    .width(style?.width)
    .height(style?.height)
    .padding(style?.padding as Padding)
    .margin(style?.margin as Margin)
    .backgroundColor(style?.backgroundColor)
    .borderRadius(style?.borderRadius as number)
    .layoutWeight(style?.layoutWeight)
    .justifyContent(style?.justifyContent)
    .alignItems(style?.alignItems)
    .opacity(style?.opacity)
    .borderColor(style?.borderColor)
    .borderWidth(style?.borderWidth);
}

@Builder
export function LynxTextArea(props: LynxInputProps) {
  const style = props.style;
  TextArea({ placeholder: props.placeholder, text: props.text })
    .onChange(props.onChange ?? undefined)
    .width(style?.width)
    .height(style?.height)
    .padding(style?.padding as Padding)
    .margin(style?.margin as Margin)
    .backgroundColor(style?.backgroundColor)
    .borderRadius(style?.borderRadius as number)
    .layoutWeight(style?.layoutWeight)
    .justifyContent(style?.justifyContent)
    .alignItems(style?.alignItems)
    .opacity(style?.opacity)
    .borderColor(style?.borderColor)
    .borderWidth(style?.borderWidth);
}

export interface LynxToggleProps {
  isOn: boolean;
  type?: ToggleType;
  style?: LynxStyle;
  onChange?: (value: boolean) => void;
}

@Builder
export function LynxToggle(props: LynxToggleProps) {
  const style = props.style;
  Toggle({ isOn: props.isOn, type: props.type ?? ToggleType.Switch })
    .onChange(props.onChange ?? undefined)
    .width(style?.width)
    .height(style?.height)
    .padding(style?.padding as Padding)
    .margin(style?.margin as Margin)
    .backgroundColor(style?.backgroundColor)
    .borderRadius(style?.borderRadius as number)
    .layoutWeight(style?.layoutWeight)
    .justifyContent(style?.justifyContent)
    .alignItems(style?.alignItems)
    .opacity(style?.opacity)
    .borderColor(style?.borderColor)
    .borderWidth(style?.borderWidth);
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
  const style = props.style;
  Tabs({ index: props.index }) {
    ForEach(props.items, (item: LynxTabItem, idx: number) => {
      TabContent() { item.builder(); }
        .tabBar({ text: item.title });
    }, (item: LynxTabItem, idx: number) => idx.toString());
  }
  .barMode(props.barMode ?? BarMode.Fixed)
  .barPosition(props.barPosition ?? BarPosition.End)
  .onChange(props.onChange ?? undefined)
  .width(style?.width)
  .height(style?.height)
  .padding(style?.padding as Padding)
  .margin(style?.margin as Margin)
  .backgroundColor(style?.backgroundColor)
  .borderRadius(style?.borderRadius as number)
  .layoutWeight(style?.layoutWeight)
  .justifyContent(style?.justifyContent)
  .alignItems(style?.alignItems)
  .opacity(style?.opacity)
  .borderColor(style?.borderColor)
  .borderWidth(style?.borderWidth);
}

export interface LynxListProps {
  style?: LynxStyle;
  divider?: ListDividerOptions;
  edgeEffect?: EdgeEffect;
}

@Builder
export function LynxList(props: LynxListProps = {}, content?: () => void) {
  const style = props.style;
  List() { content && content(); }
    .divider(props.divider)
    .edgeEffect(props.edgeEffect)
    .width(style?.width)
    .height(style?.height)
    .padding(style?.padding as Padding)
    .margin(style?.margin as Margin)
    .backgroundColor(style?.backgroundColor)
    .borderRadius(style?.borderRadius as number)
    .layoutWeight(style?.layoutWeight)
    .justifyContent(style?.justifyContent)
    .alignItems(style?.alignItems)
    .opacity(style?.opacity)
    .borderColor(style?.borderColor)
    .borderWidth(style?.borderWidth)
    .onClick(props.onClick ?? undefined);
}

export interface LynxListItemProps extends LynxContainerProps {}

@Builder
export function LynxListItem(props: LynxListItemProps = {}, content?: () => void) {
  const style = props.style;
  ListItem() { content && content(); }
    .width(style?.width)
    .height(style?.height)
    .padding(style?.padding as Padding)
    .margin(style?.margin as Margin)
    .backgroundColor(style?.backgroundColor)
    .borderRadius(style?.borderRadius as number)
    .layoutWeight(style?.layoutWeight)
    .justifyContent(style?.justifyContent)
    .alignItems(style?.alignItems)
    .opacity(style?.opacity)
    .borderColor(style?.borderColor)
    .borderWidth(style?.borderWidth)
    .onClick(props.onClick ?? undefined);
}

export interface LynxFlexProps extends LynxContainerProps { align?: Alignment; }

@Builder
export function LynxFlex(props: LynxFlexProps = {}, content?: () => void) {
  const style = props.style;
  Flex({ alignItems: style?.alignItems, justifyContent: style?.justifyContent }) {
    content && content();
  }
  .width(style?.width)
  .height(style?.height)
  .padding(style?.padding as Padding)
  .margin(style?.margin as Margin)
  .backgroundColor(style?.backgroundColor)
  .borderRadius(style?.borderRadius as number)
  .layoutWeight(style?.layoutWeight)
  .justifyContent(style?.justifyContent)
  .alignItems(style?.alignItems)
  .opacity(style?.opacity)
  .borderColor(style?.borderColor)
  .borderWidth(style?.borderWidth)
  .onClick(props.onClick ?? undefined);
}
