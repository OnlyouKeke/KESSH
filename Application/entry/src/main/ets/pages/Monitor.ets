import { ConnectionStore, ConnectionRecord } from '../common/Stores';
import { SSHEngine } from '../common/SSHEngine';
import { promptAction } from '@kit.ArkUI';
import { taskpool } from '@kit.ArkTS';

@Concurrent
function runMonitorCommand(sessionId: number, command: string): string {
  try {
    return SSHEngine.executeCommand(sessionId, command);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('Monitor command failed:', message);
    return '';
  }
}

@Entry
@Component
export struct MonitorPage {
  @State hostList: Array<ConnectionRecord> = [];
  @State selectedHost: ConnectionRecord | null = null;
  @State showHostPicker: boolean = false;
  @State cpuUsage: number = 0;
  @State cpuDetail: string = '--';
  @State memoryUsage: number = 0;
  @State memoryDetail: string = '--';
  @State diskUsage: number = 0;
  @State diskDetail: string = '--';
  @State lastUpdate: string = '';
  @State isLoading: boolean = false;
  @State sessionError: string = '';
  @State cpuHistory: Array<number> = [];
  @State memoryHistory: Array<number> = [];
  @State diskHistory: Array<number> = [];

  private sessionId: number = -1;
  private refreshTimer: number = -1;
  private currentPassword: string = '';
  private readonly historyLimit: number = 20;

  aboutToAppear(): void {
    this.refreshHosts();
  }

  aboutToDisappear(): void {
    this.cleanupSession();
  }

  private refreshHosts(): void {
    const list = ConnectionStore.list();
    this.hostList = list.filter(item => !!ConnectionStore.getPassword(item));
    if (!this.selectedHost && this.hostList.length > 0) {
      this.handleHostSelect(this.hostList[0]);
    }
  }

  private cleanupSession(): void {
    if (this.refreshTimer > 0) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
    if (this.sessionId > 0) {
      SSHEngine.closeSession(this.sessionId);
      this.sessionId = -1;
    }
  }

  private async handleHostSelect(record: ConnectionRecord): Promise<void> {
    const savedPassword = ConnectionStore.getPassword(record);
    if (!savedPassword) {
      promptAction.showToast({ message: '请先为该主机启用保存密码' });
      return;
    }
    this.showHostPicker = false;
    this.selectedHost = record;
    this.currentPassword = savedPassword;
    await this.openSession(record);
  }

  private async openSession(record: ConnectionRecord): Promise<void> {
    this.isLoading = true;
    this.sessionError = '';
    this.cleanupSession();
    try {
      const session = SSHEngine.openSession(
        record.host,
        record.port,
        record.username,
        this.currentPassword
      );
      if (session <= 0) {
        throw new Error('SSH连接失败');
      }
      this.sessionId = session;
      await this.fetchMetrics();
      this.refreshTimer = setInterval(() => {
        this.fetchMetrics();
      }, 5000) as number;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.sessionError = message;
      promptAction.showToast({ message: `连接失败: ${message}` });
    } finally {
      this.isLoading = false;
    }
  }

  private parseCpu(output: string): void {
    if (!output) {
      this.cpuUsage = 0;
      this.cpuDetail = '--';
      this.logMonitor('CPU output empty');
      return;
    }
    const idleMatch = output.match(/(\d+(?:\.\d+)?)\s*%?\s*id/i);
    if (idleMatch) {
      const idle = parseFloat(idleMatch[1]);
      const usage = 100 - idle;
      this.cpuUsage = usage;
    } else {
      // Fallback: sum user/system percentages if idle not present in expected format.
      const usageMatch = output.match(/(\d+(?:\.\d+)?)\s*us.*?(\d+(?:\.\d+)?)\s*sy/i);
      if (usageMatch) {
        this.cpuUsage = parseFloat(usageMatch[1]) + parseFloat(usageMatch[2]);
      } else {
        this.cpuUsage = 0;
        this.logMonitor(`CPU parse failed, raw="${this.safeLog(output)}"`);
      }
    }
    this.cpuDetail = output;
  }

  private parseMemory(output: string): void {
    if (!output) {
      this.memoryUsage = 0;
      this.memoryDetail = '--';
      this.logMonitor('Memory output empty');
      return;
    }
    const columns = output.replace(/\s+/g, ' ').trim().split(' ');
    if (columns.length >= 4) {
      const total = parseFloat(columns[1]);
      const used = parseFloat(columns[2]);
      const free = parseFloat(columns[3]);
      if (total > 0) {
        this.memoryUsage = (used / total) * 100;
      }
      this.memoryDetail = `?? ${total}MB ? ?? ${used}MB ? ?? ${free}MB`;
    } else {
      this.memoryDetail = output;
      this.logMonitor(`Memory parse failed, raw="${this.safeLog(output)}"`);
    }
  }

  private parseDisk(output: string): void {
    if (!output) {
      this.diskUsage = 0;
      this.diskDetail = '--';
      this.logMonitor('Disk output empty');
      return;
    }
    const columns = output.replace(/\s+/g, ' ').trim().split(' ');
    if (columns.length >= 5) {
      const percent = columns[4].replace('%', '');
      const usedRatio = parseFloat(percent);
      this.diskUsage = usedRatio;
      this.diskDetail = `?? ${columns[1]} ? ?? ${columns[2]} ? ?? ${columns[3]}`;
    } else {
      this.diskDetail = output;
      this.logMonitor(`Disk parse failed, raw="${this.safeLog(output)}"`);
    }
  }

  private async fetchMetrics(): Promise<void> {
    if (this.sessionId <= 0) {
      return;
    }
    this.isLoading = true;
    this.logMonitor(`fetchMetrics start, session=${this.sessionId}`);
    try {
      const cpuTask = new taskpool.Task(runMonitorCommand, this.sessionId,
        "LANG=C top -bn1 | grep 'Cpu(s)' | head -n 1");
      const memTask = new taskpool.Task(runMonitorCommand, this.sessionId,
        "free -m | grep -E '^Mem'");
      const diskTask = new taskpool.Task(runMonitorCommand, this.sessionId,
        "df -h / | tail -n 1");
      const outputs = await Promise.all([
        taskpool.execute(cpuTask),
        taskpool.execute(memTask),
        taskpool.execute(diskTask)
      ]) as Array<string>;

      this.parseCpu(outputs[0] || '');
      this.parseMemory(outputs[1] || '');
      this.parseDisk(outputs[2] || '');
      this.cpuHistory = this.pushHistory(this.cpuHistory, this.cpuUsage);
      this.memoryHistory = this.pushHistory(this.memoryHistory, this.memoryUsage);
      this.diskHistory = this.pushHistory(this.diskHistory, this.diskUsage);
      this.lastUpdate = new Date().toLocaleTimeString();
      this.sessionError = '';
      this.logMonitor(`CPU raw="${this.safeLog(outputs[0])}" usage=${this.cpuUsage.toFixed(2)}%`);
      this.logMonitor(`Memory raw="${this.safeLog(outputs[1])}" usage=${this.memoryUsage.toFixed(2)}%`);
      this.logMonitor(`Disk raw="${this.safeLog(outputs[2])}" usage=${this.diskUsage.toFixed(2)}%`);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.sessionError = message;
      this.logMonitor(`fetchMetrics error: ${message}`);
    } finally {
      this.isLoading = false;
    }
  }

  private clampUsage(value: number): number {
    if (value < 0) {
      return 0;
    }
    if (value > 100) {
      return 100;
    }
    return value;
  }

  private usageText(value: number): string {
    const normalized = this.clampUsage(value);
    return `${normalized.toFixed(1)}%`;
  }

  private pushHistory(history: Array<number>, value: number): Array<number> {
    const next = [...history, this.clampUsage(value)];
    if (next.length > this.historyLimit) {
      next.shift();
    }
    return next;
  }

  private getChartValues(history: Array<number>): Array<number> {
    if (!history || history.length === 0) {
      return [0];
    }
    if (history.length === 1) {
      return [history[0], history[0]];
    }
    return history;
  }

  private safeLog(text: string | undefined | null): string {
    if (!text) {
      return '';
    }
    return text.replace(/\s+/g, ' ').trim().slice(0, 200);
  }

  private logMonitor(message: string): void {
    console.info(`[Monitor] ${message}`);
  }

  @Builder
  private renderMetricCard(title: string, usage: number, summary: string, history: Array<number>) {
    Column({ space: 8 }) {
      Row() {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Blank().layoutWeight(1)
        Text(this.usageText(usage))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_emphasize'))
      }
      Stack() {
        Row({ space: 4 }) {
          ForEach(this.getChartValues(history), (value: number, index: number) => {
            Column() {
              Blank().layoutWeight(1)
              Column()
                .width(6)
                .height(`${this.clampUsage(value)}%`)
                .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
                .opacity(0.6)
                .borderRadius(3)
            }
            .width(10)
            .height(100)
          }, (value: number, index: number) => `${title}-${index}`)
        }
        .width('100%')
        .height(100)
      }
      if (summary) {
        Text(summary)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }
    }
    .padding(16)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .borderRadius(16)
  }

  @Builder
  private renderMetricPanels() {
    Column({ space: 16 }) {
      this.renderMetricCard('CPU 使用率', this.cpuUsage, this.cpuDetail, this.cpuHistory)
      this.renderMetricCard('内存使用率', this.memoryUsage, this.memoryDetail, this.memoryHistory)
      this.renderMetricCard('磁盘使用率', this.diskUsage, this.diskDetail, this.diskHistory)
    }
    .padding({ left: 16, right: 16, bottom: 24 })
  }

  @Builder
  private renderHostPicker() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0,0,0,0.35)')
        .onClick((): void => { this.showHostPicker = false; })
      Column({ space: 12 }) {
        Text('选择主机')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        if (this.hostList.length === 0) {
          Text('暂无保存密码的主机，可在“主机”板块中为主机启用“保存密码”后再试。')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        } else {
          List({ space: 8 }) {
            ForEach(this.hostList, (item: ConnectionRecord) => {
              ListItem() {
                Column({ space: 4 }) {
                  Text(item.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                  Text(`${item.host}:${item.port} · ${item.username}`)
                    .fontSize(14)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                }
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .width('100%')
              }
              .onClick((): void => { this.handleHostSelect(item); })
            }, (item: ConnectionRecord) => item.id.toString())
          }
          .edgeEffect(EdgeEffect.Spring)
          .height(260)
        }
      }
      .padding({ left: 16, right: 16, top: 16, bottom: 32 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
  }

  build() {
    Stack() {
      Column({ space: 16 }) {
        Column({ space: 8 }) {
          Row() {
            Column({ space: 4 }) {
              Text('当前主机')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              if (this.selectedHost) {
                Text(`${this.selectedHost.name}`)
                  .fontSize(14)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              } else {
                Text('请选择主机后开始监控')
                  .fontSize(14)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
            }
            .layoutWeight(1)
            Button('选择主机')
              .type(ButtonType.Normal)
              .height(32)
              .fontSize(14)
              .onClick((): void => { this.showHostPicker = true; })
          }
          if (this.lastUpdate) {
            Text(`最近更新：${this.lastUpdate}`)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          if (this.sessionError) {
            Text(`错误: ${this.sessionError}`)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_warning'))
          }
        }
        .padding({ left: 16, right: 16, top: 12 })

        Row() {
          Text('服务器监控')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Blank().layoutWeight(1)
          Button('刷新')
            .type(ButtonType.Normal)
            .height(32)
            .fontSize(14)
            .enabled(!!this.selectedHost && !this.isLoading)
            .opacity(this.isLoading ? 0.6 : 1)
            .onClick((): void => { this.fetchMetrics(); })
        }
        .padding({ left: 16, right: 16 })

        if (!this.selectedHost) {
          Column({ space: 12 }) {
            Text('尚未选择主机')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
            Text('点击上方“选择主机”按钮，选择已保存密码的主机以查看CPU、内存和磁盘信息。')
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
          .padding(32)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        } else {
          this.renderMetricPanels()
        }

        if (this.isLoading) {
          Text('正在获取最新数据...')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .padding({ left: 16, right: 16, bottom: 16 })
        }
      }
      if (this.showHostPicker) {
        this.renderHostPicker()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
