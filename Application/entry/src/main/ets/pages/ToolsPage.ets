import { router } from '@kit.ArkUI';

interface ToolItem {
  icon: string;
  title: string;
  description: string;
  route: string;
  color: ResourceStr;
}

@Component
export struct ToolsPage {
  private tools: ToolItem[] = [
    {
      icon: '🌐',
      title: 'Ping 工具',
      description: '检测主机连通性与网络延迟',
      route: 'pages/tools/PingTool',
      color: $r('sys.color.ohos_id_color_emphasize')
    },
    {
      icon: '🔢',
      title: '子网掩码计算器',
      description: '计算IP地址的子网信息',
      route: 'pages/tools/SubnetCalc',
      color: $r('sys.color.ohos_id_color_emphasize')
    },
    {
      icon: '🔐',
      title: 'Base64 编解码',
      description: '本地完成字符串的编码/解码',
      route: 'pages/tools/Base64Tool',
      color: $r('sys.color.ohos_id_color_emphasize')
    },
    {
      icon: '🔌',
      title: '端口测试',
      description: '验证指定主机端口是否开放',
      route: 'pages/tools/PortTest',
      color: $r('sys.color.ohos_id_color_emphasize')
    }
  ];

  @Builder
  toolCard(item: ToolItem) {
    Column({ space: 12 }) {
      Row({ space: 16 }) {
        // 图标
        Text(item.icon)
          .fontSize(48)
          .width(64)
          .height(64)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
          .borderRadius(16)
        
        // 文字区域
        Column({ space: 4 }) {
          Text(item.title)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          Text(item.description)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        
        // 箭头
        Text('>')
          .fontSize(20)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .borderRadius(16)
    .onClick((): void => {
      router.pushUrl({ url: item.route });
    })
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        // 页面描述
        Column({ space: 8 }) {
          Text('🛠️ 实用工具集')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
          Text('提供网络诊断、数据转换等常用工具，所有工具均在本地运行')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(16)
        .alignItems(HorizontalAlign.Start)

        // 工具列表
        ForEach(this.tools, (item: ToolItem) => {
          this.toolCard(item);
        }, (item: ToolItem) => item.route)
      }
      .padding(16)
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .layoutWeight(1)
    .width('100%')
  }
}
