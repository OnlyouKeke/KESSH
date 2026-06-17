import { router } from '@kit.ArkUI';

/**
 * HarmonyOS shell page that hosts the ReactLynx UI built from the
 * sibling `lynx-app/` project.
 *
 * The Lynx bundle ships as a HarmonyOS rawfile at
 *   `entry/src/main/resources/rawfile/main.lynx.bundle`
 * (see `lynx-app/README.md` for the build / copy command).
 *
 * Once `@lynx/lynx@next` is installed via `ohpm install`, the import below
 * resolves to the LynxView ArkUI component. While the bundle is missing
 * the page renders a friendly fallback so the app still launches.
 */

@Entry
@Component
struct LynxHostPage {
  @State bundleAvailable: boolean = true;
  @State errorMessage: string = '';

  build() {
    Column() {
      // The ArkUI side keeps a thin top bar so the user can leave the Lynx
      // sub-app and return to legacy ArkTS pages while the migration is in
      // progress. Once every page is migrated, this header can be removed
      // and `LynxHostPage` becomes the entry page directly.
      Row() {
        Text('< 返回 ArkUI 主界面')
          .fontSize(14)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick((): void => { router.back(); })
        Blank().layoutWeight(1)
      }
      .width('100%')

      if (this.bundleAvailable) {
        // NOTE: LynxView is provided by the @lynx/lynx@next ohpm package.
        // After running `ohpm install` in `Application/` the import below
        // becomes available. Until then this branch is rendered as a
        // friendly placeholder rather than crashing the app.
        //
        // import { LynxView } from '@lynx/lynx';
        //
        // LynxView({
        //   url: $rawfile('main.lynx.bundle')
        // })
        //   .width('100%')
        //   .layoutWeight(1)
        //   .onError((event: { message: string }) => {
        //     this.bundleAvailable = false;
        //     this.errorMessage = event.message;
        //   })
        Column() {
          Text('Lynx UI placeholder')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 })
          Text('当前 ArkUI 占位实现。请先在 lynx-app/ 中运行 pnpm build 并将 dist/main.lynx.bundle 复制到 entry/src/main/resources/rawfile/，再启用上方注释中的 LynxView 调用。')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(24)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Column() {
          Text('Lynx UI 加载失败')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 8 })
            .textAlign(TextAlign.Center)
          Button('返回 ArkUI 界面')
            .margin({ top: 16 })
            .onClick((): void => { router.back(); })
        }
        .width('100%')
        .layoutWeight(1)
        .padding(24)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
