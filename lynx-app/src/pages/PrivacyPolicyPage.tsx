import { Card, PageHeader } from '../components/Page';
import type { ReactNode } from '@lynx-js/react';

interface Section {
  heading: string;
  paragraphs: ReactNode[];
}

const SECTIONS: Section[] = [
  {
    heading: 'KESSH 隐私政策',
    paragraphs: [
      'KESSH 是由张惟钧（以下简称"我们"）为您提供的，用于终端 SSH 连接的应用。本隐私声明由我们为处理您的个人信息而制定。',
      '我们非常重视您的个人信息和隐私保护，将会按照法律要求和业界成熟的安全标准，为您的个人信息提供相应的安全保护措施。'
    ]
  },
  {
    heading: '1. 我们如何收集和使用您的个人信息',
    paragraphs: [
      '我们仅在有合法性基础的情形下才会使用您的个人信息。根据适用的法律，我们可能会基于您的同意、为履行/订立您与我们的合同所必需、履行法定义务所必需等合法性基础，使用您的个人信息。',
      '1.1 密钥跨设备管理功能：我们为您提供密钥跨设备管理功能，在您使用相关业务的过程中，我们会处理所必需的信息，以便履行我们的合同义务。',
      '为了实现应用功能，在获取您的同意后，我们需要收集您的用户标识符。'
    ]
  },
  {
    heading: '2. 设备权限调用',
    paragraphs: [
      '图片和视频：在使用 SCP 功能时，需要访问该权限以便上传和下载文件。'
    ]
  },
  {
    heading: '3. 管理您的个人信息',
    paragraphs: [
      '如您对您的数据主体权利有进一步要求或存在任何疑问、意见或建议，可通过本声明中"如何联系我们"章节中所述方式与我们取得联系，并行使您的相关权利。'
    ]
  },
  {
    heading: '4. 信息存储地点及期限',
    paragraphs: [
      '4.1 我们承诺，除法律法规另有规定外，我们对您的信息的保存期限应当为实现处理目的所必要的最短时间。',
      '4.2 所有数据均存储于您的本地设备，不会上传至任何服务器。SSH 密码使用 AES-128-GCM 算法加密存储于应用沙箱中，确保数据安全。'
    ]
  },
  {
    heading: '5. 如何联系我们',
    paragraphs: [
      '邮箱：zwjkeke@foxmail.com',
      '更新日期：2025.11.13 · 生效日期：2025.11.13'
    ]
  }
];

export function PrivacyPolicyPage() {
  return (
    <view className="page">
      <PageHeader title="隐私协议" />
      <scroll-view scroll-y style={{ flex: 1, padding: 16 }}>
        {SECTIONS.map((section) => (
          <Card key={section.heading} className="card-section">
            <text className="card-title">{section.heading}</text>
            {section.paragraphs.map((paragraph, index) => (
              <text key={`${index}`} className="card-subtitle" style={{ marginTop: 8, lineHeight: 22 }}>{paragraph}</text>
            ))}
          </Card>
        ))}
      </scroll-view>
    </view>
  );
}
