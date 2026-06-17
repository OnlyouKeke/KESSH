export interface LynxStyle {
  width?: string | number;
  height?: string | number;
  padding?: Padding | number | string;
  margin?: Margin | number | string;
  backgroundColor?: string | Color;
  borderRadius?: number | string;
  layoutWeight?: number;
  justifyContent?: FlexAlign;
  alignItems?: ItemAlign | HorizontalAlign | VerticalAlign;
  opacity?: number;
  borderColor?: string | Color;
  borderWidth?: number;
}

export interface LynxContainerProps {
  style?: LynxStyle;
  space?: number;
  onClick?: () => void;
}

@Component
export struct LynxColumn {
  @Prop style?: LynxStyle;
  @Prop space?: number;
  onTap?: () => void;
  @BuilderParam content?: () => void;

  build() {
    Column({ space: this.space ?? 0 }) {
      if (this.content) {
        this.content()
      }
    }
    .width(this.style?.width)
    .height(this.style?.height)
    .padding(this.style?.padding as Padding)
    .margin(this.style?.margin as Margin)
    .backgroundColor(this.style?.backgroundColor)
    .borderRadius(this.style?.borderRadius as number)
    .layoutWeight(this.style?.layoutWeight)
    .justifyContent(this.style?.justifyContent as FlexAlign)
    .alignItems(this.style?.alignItems as HorizontalAlign)
    .opacity(this.style?.opacity)
    .borderColor(this.style?.borderColor)
    .borderWidth(this.style?.borderWidth)
    .onClick((_event: ClickEvent): void => { this.onTap?.(); });
  }
}

@Component
export struct LynxRow {
  @Prop style?: LynxStyle;
  @Prop space?: number;
  onTap?: () => void;
  @BuilderParam content?: () => void;

  build() {
    Row({ space: this.space ?? 0 }) {
      if (this.content) {
        this.content()
      }
    }
    .width(this.style?.width)
    .height(this.style?.height)
    .padding(this.style?.padding as Padding)
    .margin(this.style?.margin as Margin)
    .backgroundColor(this.style?.backgroundColor)
    .borderRadius(this.style?.borderRadius as number)
    .layoutWeight(this.style?.layoutWeight)
    .justifyContent(this.style?.justifyContent as FlexAlign)
    .alignItems(this.style?.alignItems as VerticalAlign)
    .opacity(this.style?.opacity)
    .borderColor(this.style?.borderColor)
    .borderWidth(this.style?.borderWidth)
    .onClick((_event: ClickEvent): void => { this.onTap?.(); });
  }
}

export interface LynxScrollProps extends LynxContainerProps {
  scrollBar?: BarState;
}

@Component
export struct LynxScroll {
  @Prop style?: LynxStyle;
  @Prop scrollBar?: BarState;
  @Prop onTap?: () => void;
  @BuilderParam content?: () => void;

  build() {
    Scroll() {
      if (this.content) {
        this.content()
      }
    }
    .scrollBar(this.scrollBar ?? BarState.Off)
    .width(this.style?.width)
    .height(this.style?.height)
    .padding(this.style?.padding as Padding)
    .margin(this.style?.margin as Margin)
    .backgroundColor(this.style?.backgroundColor)
    .borderRadius(this.style?.borderRadius as number)
    .layoutWeight(this.style?.layoutWeight)
    .opacity(this.style?.opacity)
    .borderColor(this.style?.borderColor)
    .borderWidth(this.style?.borderWidth)
    .onClick((_event: ClickEvent): void => { this.onTap?.(); });
  }
}

export interface LynxTextStyle extends LynxStyle {
  fontSize?: number | string;
  fontWeight?: FontWeight;
  fontFamily?: string;
  fontColor?: string | Color;
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
    .fontFamily(props.style?.fontFamily)
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
  fontColor?: string | Color;
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

export interface LynxListProps {
  style?: LynxStyle;
  divider?: ListDividerOptions;
  edgeEffect?: EdgeEffect;
  onClick?: () => void;
}

@Component
export struct LynxList {
  @Prop style?: LynxStyle;
  @Prop divider?: ListDividerOptions;
  @Prop edgeEffect?: EdgeEffect;
  onTap?: () => void;
  @BuilderParam content?: () => void;

  build() {
    List() {
      if (this.content) {
        this.content()
      }
    }
    .divider(this.divider)
    .edgeEffect(this.edgeEffect)
    .width(this.style?.width)
    .height(this.style?.height)
    .padding(this.style?.padding as Padding)
    .margin(this.style?.margin as Margin)
    .backgroundColor(this.style?.backgroundColor)
    .borderRadius(this.style?.borderRadius as number)
    .layoutWeight(this.style?.layoutWeight)
    .opacity(this.style?.opacity)
    .borderColor(this.style?.borderColor)
    .borderWidth(this.style?.borderWidth)
    .onClick((_event: ClickEvent): void => { this.onTap?.(); });
  }
}

export interface LynxListItemProps extends LynxContainerProps {}

@Component
export struct LynxListItem {
  @Prop style?: LynxStyle;
  onTap?: () => void;
  @BuilderParam content?: () => void;

  build() {
    ListItem() {
      if (this.content) {
        this.content()
      }
    }
    .width(this.style?.width)
    .height(this.style?.height)
    .padding(this.style?.padding as Padding)
    .margin(this.style?.margin as Margin)
    .backgroundColor(this.style?.backgroundColor)
    .borderRadius(this.style?.borderRadius as number)
    .layoutWeight(this.style?.layoutWeight)
    .opacity(this.style?.opacity)
    .borderColor(this.style?.borderColor)
    .borderWidth(this.style?.borderWidth)
    .onClick((_event: ClickEvent): void => { this.onTap?.(); });
  }
}

export interface LynxFlexProps extends LynxContainerProps { align?: Alignment; }

@Component
export struct LynxFlex {
  @Prop style?: LynxStyle;
  onTap?: () => void;
  @BuilderParam content?: () => void;

  build() {
    Flex({ alignItems: this.style?.alignItems as ItemAlign, justifyContent: this.style?.justifyContent as FlexAlign }) {
      if (this.content) {
        this.content()
      }
    }
    .width(this.style?.width)
    .height(this.style?.height)
    .padding(this.style?.padding as Padding)
    .margin(this.style?.margin as Margin)
    .backgroundColor(this.style?.backgroundColor)
    .borderRadius(this.style?.borderRadius as number)
    .layoutWeight(this.style?.layoutWeight)
    .opacity(this.style?.opacity)
    .borderColor(this.style?.borderColor)
    .borderWidth(this.style?.borderWidth)
    .onClick((_event: ClickEvent): void => { this.onTap?.(); });
  }
}
