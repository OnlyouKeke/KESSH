import { Card, PageHeader } from '../components/Page';
import { KesshHost } from '../native/host';

const FEEDBACK_TYPES = ['功能异常或 BUG', '新功能建议', '体验优化建议', '其他问题与建议'];
const PRIMARY_EMAIL = 'kekeformp1@163.com';
const BACKUP_EMAIL = 'zwjkeke@foxmail.com';

export function FeedbackPage() {
  async function copy(text: string) {
    await KesshHost.writeClipboard(text).catch(() => undefined);
    await KesshHost.showToast(`已复制 ${text}`).catch(() => undefined);
  }

  return (
    <view className="page">
      <PageHeader title="问题反馈" />
      <scroll-view scroll-y style={{ flex: 1, padding: 16 }}>
        <Card>
          <text style={{ fontSize: 56, textAlign: 'center' }}>📧</text>
          <text className="card-title" style={{ textAlign: 'center', marginTop: 12 }}>欢迎反馈问题与建议</text>
          <text className="card-subtitle" style={{ textAlign: 'center', marginTop: 8 }}>
            感谢您使用 KESSH！您的反馈对我们至关重要，将帮助我们不断改进产品体验。
          </text>
        </Card>

        <Card>
          <text className="card-title">您可以反馈以下内容</text>
          {FEEDBACK_TYPES.map((item) => (
            <text key={item} className="card-subtitle" style={{ marginTop: 6 }}>• {item}</text>
          ))}
        </Card>

        <Card onTap={() => copy(PRIMARY_EMAIL)}>
          <text className="card-subtitle">反馈邮箱（点击复制）</text>
          <text className="card-title" style={{ color: 'var(--primary)', marginTop: 4 }}>{PRIMARY_EMAIL}</text>
        </Card>
        <Card onTap={() => copy(BACKUP_EMAIL)}>
          <text className="card-subtitle">备用邮箱（点击复制）</text>
          <text className="card-title" style={{ color: 'var(--primary)', marginTop: 4 }}>{BACKUP_EMAIL}</text>
        </Card>

        <Card>
          <text className="card-title">💡 反馈指南</text>
          <text className="card-subtitle" style={{ marginTop: 8, lineHeight: 22 }}>
            为了更好地帮助您解决问题，建议您在邮件中包含以下信息：
          </text>
          <text className="card-subtitle">1. 问题描述：详细描述遇到的问题</text>
          <text className="card-subtitle">2. 复现步骤：如何复现该问题</text>
          <text className="card-subtitle">3. 设备信息：手机型号和系统版本</text>
          <text className="card-subtitle">4. 应用版本：当前使用的 KESSH 版本</text>
          <text className="card-subtitle">5. 截图或日志：如果可能，请附上截图</text>
        </Card>

        <text className="card-subtitle" style={{ textAlign: 'center', marginTop: 8 }}>
          再次感谢您的支持，我们会认真处理每一条反馈！
        </text>
      </scroll-view>
    </view>
  );
}
