import { router } from '@kit.ArkUI';

/**
 * HarmonyOS shell page that hosts the ReactLynx UI built from the
 * sibling `lynx-app/` project.
 *
 * The Lynx bundle ships as a HarmonyOS rawfile at
 *   `entry/src/main/resources/rawfile/main.lynx.bundle`
 * (see `lynx-app/README.md` for the build / copy command).
 *
 * Once `@lynx/lynx@next` is installed via `ohpm install`, replace the
 * placeholder Column below with:
 *
 *   import { LynxView } from '@lynx/lynx';
 *
 *   LynxView({ url: $rawfile('main.lynx.bundle') })
 *     .width('100%')
 *     .layoutWeight(1)
 *     .onError((event: { message: string }) => {
 *       this.bundleAvailable = false;
 *       this.errorMessage = event.message;
 *     })
 *
 * The KesshHost NativeModule is registered in `EntryAbility.onCreate`. When
 * `@lynx/lynx@next` is wired up the ReactLynx side calls it via
 * `NativeModules.KesshHost`.
 */

@Entry
@Component
struct LynxHostPage {
  @State bundleAvailable: boolean = true;
  @State errorMessage: string = '';

  build() {
    Column() {
      if (this.bundleAvailable) {
        Column() {
          Text('Lynx UI 占位')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 8 })
          Text('当前位置已切换为 Lynx UI 入口。请在 lynx-app/ 中运行 npm run build 并把 dist/main.lynx.bundle 复制到 entry/src/main/resources/rawfile/，然后启用 LynxView 调用即可看到 ReactLynx 页面。')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .textAlign(TextAlign.Center)
            .lineHeight(20)
          Button('使用 ArkUI 旧界面')
            .type(ButtonType.Capsule)
            .height(40)
            .margin({ top: 16 })
            .onClick((): void => {
              router.replaceUrl({ url: 'pages/Index' });
            })
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
          Button('回到 ArkUI 旧界面')
            .type(ButtonType.Capsule)
            .margin({ top: 16 })
            .onClick((): void => {
              router.replaceUrl({ url: 'pages/Index' });
            })
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
