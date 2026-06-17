import { Card, PageHeader } from '../components/Page';

const SECTIONS: { heading: string; lines: string[] }[] = [
  {
    heading: 'KESSH 用户服务协议',
    lines: [
      '欢迎使用 KESSH！',
      '本协议由张惟钧（以下简称"我们"）与您（以下简称"用户"）共同签订。在使用 KESSH 应用程序（以下简称"本应用"）之前，请您仔细阅读本协议。您下载、安装和使用本应用，即表示您已经阅读、理解并同意受本协议的约束。'
    ]
  },
  {
    heading: '1. 服务内容',
    lines: [
      '本应用是一款用于 SSH 远程连接的终端工具，提供以下主要功能：',
      '• SSH 远程连接功能',
      '• SCP 文件传输功能',
      '• SSH 密钥管理',
      '• 连接历史记录',
      '• 多账号数据隔离'
    ]
  },
  {
    heading: '2. 用户权利与义务',
    lines: [
      '2.1 用户权利',
      '• 您有权免费使用本应用的所有功能',
      '• 您的所有数据均存储在本地设备，您拥有完全控制权',
      '• 您可以随时导出或删除您的数据',
      '2.2 用户义务',
      '• 您应合法使用本应用，不得用于任何非法目的',
      '• 您应妥善保管 SSH 密码和私钥',
      '• 您应对使用本应用连接的远程服务器承担相应责任'
    ]
  },
  {
    heading: '3. 隐私保护',
    lines: [
      '我们非常重视您的隐私保护：',
      '• 所有数据均存储在您的本地设备，不会上传至任何服务器',
      '• SSH 密码使用 AES-128-GCM 算法加密存储',
      '• 不同华为账号的数据完全隔离',
      '• 不收集任何个人敏感信息'
    ]
  },
  {
    heading: '4. 免责声明',
    lines: [
      '本应用按"原样"提供，我们不对以下情况承担责任：',
      '• 由于网络故障、设备故障等原因导致的服务中断',
      '• 用户不当使用导致的任何损失',
      '• 用户未妥善保管密码导致的安全问题',
      '• 第三方服务器的安全问题'
    ]
  },
  {
    heading: '5. 协议修改',
    lines: [
      '我们有权在必要时修改本协议。协议修改后，如果您继续使用本应用，即视为您已接受修改后的协议。若您不同意修改后的内容，请停止使用本应用。'
    ]
  },
  {
    heading: '6. 联系我们',
    lines: [
      '如您对本协议有任何疑问，请联系：',
      '邮箱：zwjkeke@foxmail.com',
      '更新日期：2025.11.13 · 生效日期：2025.11.13'
    ]
  }
];

export function UserAgreementPage() {
  return (
    <view className="page">
      <PageHeader title="用户协议" />
      <scroll-view scroll-y style={{ flex: 1, padding: 16 }}>
        {SECTIONS.map((section) => (
          <Card key={section.heading}>
            <text className="card-title">{section.heading}</text>
            {section.lines.map((line, index) => (
              <text key={`${index}`} className="card-subtitle" style={{ marginTop: 8, lineHeight: 22 }}>{line}</text>
            ))}
          </Card>
        ))}
      </scroll-view>
    </view>
  );
}
