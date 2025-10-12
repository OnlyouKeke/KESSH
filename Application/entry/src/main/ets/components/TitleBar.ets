@Component
export default struct TitleBar {
  @Prop title: string = '';
  @Prop showActions: boolean = false;

  build() {
    Row() {
      // 左侧标题；若为空，用 16vp 占位保持对齐
      if (this.title && this.title.length > 0) {
        Text(this.title)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .lineHeight(28)
          .margin({ left: 16 })
      } else {
        Blank().width(16)
      }

      Blank().layoutWeight(1)

      // 右侧操作区：默认不显示；需要时作为 36vp 胶囊按钮组
      if (this.showActions) {
        Row() {
          Button('···')
            .type(ButtonType.Normal)
            .height(36)
            .width(36)
            .fontSize(18)
          Blank().width(8)
          Button('—')
            .type(ButtonType.Normal)
            .height(36)
            .width(36)
            .fontSize(18)
        }
        .padding({ left: 12, right: 12 })
        .margin({ right: 16 })
        .backgroundColor('#0F000000')
        .borderRadius(18)
        .height(36)
      } else {
        // 右侧占位，保持边距
        Blank().width(16)
      }
    }
    .height(56)
    .width('100%')
  }
}