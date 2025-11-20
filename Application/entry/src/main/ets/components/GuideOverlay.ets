import { GuideStep, GuideProgress } from '../common/GuideManager';

/**
 * 新手引导浮层组件 - 底部卡片式设计
 */
@Component
export struct GuideOverlay {
  @Prop currentStep: GuideStep | null = null;
  @Prop progress: GuideProgress = { current: 1, total: 7 };
  onNext: () => void = () => {};
  onPrevious: () => void = () => {};
  onSkip: () => void = () => {};
  onComplete: () => void = () => {};

  build() {
    if (!this.currentStep) {
      Column().width(0).height(0);
    } else {
      Column() {
        Blank().layoutWeight(1)
        
        // 底部引导卡片
        Column({ space: 16 }) {
          // 进度指示器
          Row({ space: 6 }) {
            ForEach(Array.from<number, number>({ length: this.progress.total }, (_v: number, i: number): number => i), (index: number) => {
              Divider()
                .width(index < this.progress.current ? 32 : 8)
                .height(3)
                .color(index < this.progress.current 
                  ? $r('sys.color.ohos_id_color_emphasize') 
                  : $r('sys.color.ohos_id_color_fourth'))
                .borderRadius(2)
            }, (index: number) => `progress_${index}`)
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          
          // 标题
          Text(this.currentStep!.title)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .width('100%')
          
          // 描述
          Text(this.currentStep!.description)
            .fontSize(15)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .lineHeight(22)
          
          // 按钮组
          Row({ space: 12 }) {
            // 跳过按钮
            if (this.currentStep!.id !== 'complete') {
              Text('跳过')
                .fontSize(15)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .onClick(() => { this.onSkip(); })
            }
            
            Blank().layoutWeight(1)
            
            // 上一步按钮
            if (this.progress.current > 1) {
              Button('上一步')
                .type(ButtonType.Normal)
                .height(40)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .borderRadius(20)
                .onClick(() => { this.onPrevious(); })
            }
            
            // 下一步/完成按钮
            Button(this.currentStep!.id === 'complete' ? '开始使用' : '下一步')
              .type(ButtonType.Normal)
              .height(40)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
              .fontColor(Color.White)
              .borderRadius(20)
              .onClick(() => {
                if (this.currentStep?.id === 'complete') {
                  this.onComplete();
                } else {
                  this.onNext();
                }
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 20 })
        .backgroundColor($r('sys.color.ohos_id_color_background'))
        .borderRadius({ topLeft: 24, topRight: 24 })
        .shadow({
          radius: 20,
          color: 'rgba(0, 0, 0, 0.08)',
          offsetX: 0,
          offsetY: -4
        })
      }
      .width('100%')
      .height('100%')
    }
  }
}
