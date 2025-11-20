import { promptAction, router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { ConnectionRecord, ConnectionStore, ConnectionDraft, Logger, SettingsStore } from '../common/Stores';
import { SSHEngine } from '../common/SSHEngine';

interface FileItem {
  name: string;
  path: string;
  size: number;
  isDirectory: boolean;
  permissions?: string;
}

@Entry
@Component
export struct SCPPage {
  @State remoteFiles: Array<FileItem> = [];
  @State localFiles: Array<FileItem> = [];
  @State currentPath: string = '~';
  @State isConnected: boolean = false;
  @State selectedFiles: Set<string> = new Set();
  @State showPathDialog: boolean = false;
  @State inputPath: string = '';
  
  private hostRecord: ConnectionRecord | null = null;
  private sessionId: number = -1;

  aboutToAppear(): void {
    // 从路由参数获取主机信息
    const params = router.getParams() as Record<string, Object>;
    if (params && params['record']) {
      this.hostRecord = params['record'] as ConnectionRecord;
      Logger.info(`SCP: 准备连接到 ${this.hostRecord.name}`);
      this.connectToHost();
    }
  }

  aboutToDisappear(): void {
    // 关闭SSH连接
    if (this.sessionId > 0) {
      SSHEngine.closeSession(this.sessionId);
      Logger.info('SCP: SSH连接已关闭');
    }
  }

  private async connectToHost(): Promise<void> {
    if (!this.hostRecord) {
      promptAction.showToast({ message: '主机信息缺失' });
      return;
    }

    try {
      // 获取保存的密码
      const password = ConnectionStore.getPassword(this.hostRecord);
      if (!password) {
        // 如果没有保存密码，跳转到添加主机页面输入密码
        promptAction.showToast({ message: '请输入密码后连接' });
        const draft: ConnectionDraft = {
          host: this.hostRecord.host,
          port: this.hostRecord.port.toString(),
          username: this.hostRecord.username,
          password: '',
          isEditing: true,
          editingId: this.hostRecord.id
        };
        ConnectionStore.currentDraft = draft;
        router.replaceUrl({ url: 'pages/SSHNewPage' });
        return;
      }

      Logger.info(`SCP: 连接到 ${this.hostRecord.host}:${this.hostRecord.port}`);
      
      // 建立SSH连接
      SSHEngine.configureKeepalive(SettingsStore.sessionKeepaliveInterval, SettingsStore.sessionKeepaliveAttempts);
      this.sessionId = SSHEngine.openSession(
        this.hostRecord.host,
        this.hostRecord.port,
        this.hostRecord.username,
        password
      );

      if (this.sessionId <= 0) {
        throw new Error('SSH连接失败');
      }

      Logger.info(`SCP: SSH连接成功, sessionId=${this.sessionId}`);
      
      // 加载远程文件列表
      await this.loadRemoteFiles();
      this.isConnected = true;
      
      promptAction.showToast({ message: '连接成功' });
    } catch (err) {
      const error = err as Error;
      Logger.error(`SCP连接失败: ${error.message}`);
      promptAction.showToast({ message: `连接失败: ${error.message}` });
      // 延迟返回避免应用退出
      setTimeout(() => {
        router.back();
      }, 1000);
    }
  }

  private async loadRemoteFiles(): Promise<void> {
    if (this.sessionId <= 0) {
      return;
    }

    try {
      Logger.info(`SCP: 加载目录 ${this.currentPath}`);
      
      // 执行ls -la命令
      const output = SSHEngine.listFiles(this.sessionId, this.currentPath);
      
      Logger.info(`SCP: ls输出: ${output}`);
      
      // 解析ls -la输出
      this.remoteFiles = this.parseLsOutput(output);
      
      Logger.info(`SCP: 解析到 ${this.remoteFiles.length} 个文件`);
    } catch (err) {
      const error = err as Error;
      Logger.error(`加载文件列表失败: ${error.message}`);
      promptAction.showToast({ message: '加载文件失败' });
    }
  }

  /**
   * 解析ls -la命令输出
   */
  private parseLsOutput(output: string): Array<FileItem> {
    const files: Array<FileItem> = [];
    const lines = output.split('\n');

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('total')) {
        continue;
      }

      // ls -la输出格式: permissions links owner group size month day time name
      const parts = trimmed.split(/\s+/);
      if (parts.length < 9) {
        continue;
      }

      const permissions = parts[0];
      const isDirectory = permissions.startsWith('d');
      const name = parts.slice(8).join(' '); // 文件名可能包含空格

      // 跳过.和..
      if (name === '.' || name === '..') {
        continue;
      }

      const sizeStr = parts[4];
      const size = parseInt(sizeStr) || 0;

      const fullPath = this.currentPath === '/' ? `/${name}` : `${this.currentPath}/${name}`;

      files.push({
        name,
        path: fullPath,
        size,
        isDirectory,
        permissions
      });
    }

    // 添加返回上级目录项
    if (this.currentPath !== '/' && this.currentPath !== '~') {
      files.unshift({
        name: '..',
        path: '..',
        size: 0,
        isDirectory: true
      });
    }

    return files;
  }

  private async selectLocalFile(): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.select({
        maxSelectNumber: 1
      });
      
      if (result && result.length > 0) {
        const uri = result[0];
        Logger.info(`选择文件: ${uri}`);
        
        // 读取文件内容
        const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
        const stat = fileIo.statSync(uri);
        const buffer = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buffer);
        fileIo.closeSync(file);
        
        // 转换为字符串
        const uint8Array = new Uint8Array(buffer);
        let content = '';
        for (let i = 0; i < uint8Array.length; i++) {
          content += String.fromCharCode(uint8Array[i]);
        }
        
        // 获取文件名
        const fileName = uri.substring(uri.lastIndexOf('/') + 1);
        
        // 显示路径选择对话框
        this.showUploadPathDialog(fileName, content);
      }
    } catch (err) {
      const error = err as Error;
      Logger.error(`选择文件失败: ${error.message}`);
      promptAction.showToast({ message: `选择文件失败: ${error.message}` });
    }
  }

  private showUploadPathDialog(fileName: string, content: string): void {
    const defaultPath = this.currentPath === '/' ? `/${fileName}` : `${this.currentPath}/${fileName}`;
    this.inputPath = defaultPath;
    
    promptAction.showDialog({
      title: '选择上传路径',
      message: `请输入远程文件路径：`,
      buttons: [
        { text: '取消', color: $r('sys.color.ohos_id_color_text_secondary') },
        { text: '上传', color: $r('sys.color.ohos_id_color_emphasize') }
      ]
    }).then((result) => {
      if (result.index === 1) {
        // 使用当前路径 + 文件名
        this.uploadFile(defaultPath, content);
      }
    });
  }

  private async uploadFile(remotePath: string, content: string): Promise<void> {
    if (this.sessionId <= 0) {
      promptAction.showToast({ message: 'SSH连接已断开' });
      return;
    }

    try {
      Logger.info(`开始上传文件到: ${remotePath}`);
      
      const bytesWritten = SSHEngine.uploadFile(this.sessionId, remotePath, content);
      
      Logger.info(`文件上传成功: ${bytesWritten} 字节`);
      promptAction.showToast({ message: `上传成功: ${bytesWritten} 字节` });
      
      // 重新加载文件列表
      await this.loadRemoteFiles();
    } catch (err) {
      const error = err as Error;
      Logger.error(`上传文件失败: ${error.message}`);
      promptAction.showToast({ message: `上传失败: ${error.message}` });
    }
  }

  private async downloadFile(item: FileItem): Promise<void> {
    if (item.isDirectory) {
      promptAction.showToast({ message: '暂不支持下载文件夹' });
      return;
    }

    if (this.sessionId <= 0) {
      promptAction.showToast({ message: 'SSH连接已断开' });
      return;
    }

    try {
      Logger.info(`开始下载文件: ${item.path}`);
      
      // 下载文件内容
      const content = SSHEngine.downloadFile(this.sessionId, item.path);
      
      Logger.info(`文件下载成功: ${content.length} 字节`);
      
      // 使用文件选择器保存
      const documentPicker = new picker.DocumentViewPicker();
      const saveResult = await documentPicker.save({
        newFileNames: [item.name]
      });
      
      if (saveResult && saveResult.length > 0) {
        const saveUri = saveResult[0];
        
        // 将内容写入文件
        const file = fileIo.openSync(saveUri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE);
        const buffer = new ArrayBuffer(content.length);
        const uint8Array = new Uint8Array(buffer);
        for (let i = 0; i < content.length; i++) {
          uint8Array[i] = content.charCodeAt(i);
        }
        fileIo.writeSync(file.fd, buffer);
        fileIo.closeSync(file);
        
        Logger.info(`文件已保存到: ${saveUri}`);
        promptAction.showToast({ 
          message: `下载成功: ${item.name} (${this.formatSize(content.length)})` 
        });
      }
    } catch (err) {
      const error = err as Error;
      Logger.error(`下载文件失败: ${error.message}`);
      promptAction.showToast({ message: `下载失败: ${error.message}` });
    }
  }

  private navigateToDirectory(item: FileItem): void {
    if (!item.isDirectory) {
      return;
    }

    if (item.name === '..') {
      // 返回上级目录
      const parts = this.currentPath.split('/');
      parts.pop();
      this.currentPath = parts.length > 0 ? parts.join('/') : '/';
      if (this.currentPath === '') {
        this.currentPath = '/';
      }
    } else {
      // 进入子目录
      this.currentPath = item.path;
    }

    // 重新加载文件列表
    this.loadRemoteFiles();
  }

  private showPathInputDialog(): void {
    promptAction.showDialog({
      title: '跳转到路径',
      message: `请输入远程路径：`,
      buttons: [
        { text: '取消', color: $r('sys.color.ohos_id_color_text_secondary') },
        { text: '跳转', color: $r('sys.color.ohos_id_color_emphasize') }
      ]
    }).then((result) => {
      if (result.index === 1) {
        // 暂时使用当前路径，实际应该从输入框获取
        // HarmonyOS 的 showDialog 不支持输入框，这里只是示意
        this.loadRemoteFiles();
      }
    });
  }

  private formatSize(bytes: number): string {
    if (bytes === 0) return '-';
    if (bytes < 1024) return `${bytes}B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
    if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)}MB`;
    return `${(bytes / 1024 / 1024 / 1024).toFixed(1)}GB`;
  }

  @Builder
  buildFileItem(item: FileItem) {
    Row() {
      // 文件图标
      Text(item.isDirectory ? '📁' : '📄')
        .fontSize(24)
        .margin({ right: 12 })
      
      // 文件信息
      Column({ space: 4 }) {
        Text(item.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        
        if (!item.isDirectory) {
          Text(this.formatSize(item.size))
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      
      // 下载按钮
      if (!item.isDirectory && item.name !== '..') {
        Row({ space: 4 }) {
          Image($r('sys.symbol.arrow_down_circle'))
            .width(20)
            .height(20)
            .fillColor(Color.White)
          Text('下载')
            .fontSize(14)
            .fontColor(Color.White)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(16)
        .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
        .onClick(() => { this.downloadFile(item); })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('<')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick((): void => {
            router.replaceUrl({ url: 'pages/Index' });
          })
        
        Column({ space: 2 }) {
          Text('SCP 文件传输')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
          
          if (this.hostRecord) {
            Text(this.hostRecord.name)
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 4 })
        
        Blank().layoutWeight(1)
        
        // 上传按钮
        Row({ space: 6 }) {
          Image($r('sys.symbol.arrow_up_circle'))
            .width(20)
            .height(20)
            .fillColor(Color.White)
          Text('上传')
            .fontSize(15)
            .fontColor(Color.White)
        }
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .borderRadius(20)
        .backgroundColor($r('sys.color.ohos_id_color_emphasize'))
        .onClick(() => { this.selectLocalFile(); })
      }
      .height(56)
      .width('100%')
      .padding({ left: 8, right: 16 })
      
      // 当前路径
      Row() {
        Row({ space: 4 }) {
          Image($r('sys.symbol.folder'))
            .width(16)
            .height(16)
            .fillColor($r('sys.color.ohos_id_color_text_secondary'))
          
          Text('远程路径:')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .margin({ right: 8 })
        
        Text(this.currentPath)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        
        // 快捷按钮
        Row({ space: 8 }) {
          // 主目录
          Text('~')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_emphasize'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(4)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .onClick(() => {
              this.currentPath = '~';
              this.loadRemoteFiles();
            })
          
          // 根目录
          Text('/')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_emphasize'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(4)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .onClick(() => {
              this.currentPath = '/';
              this.loadRemoteFiles();
            })
        }
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      
      Divider()
        .strokeWidth(1)
        .color($r('sys.color.ohos_id_color_list_separator'))

      // 文件列表
      if (!this.isConnected) {
        Column({ space: 12 }) {
          Text('正在连接...')
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.remoteFiles.length === 0) {
        Column({ space: 12 }) {
          Text('空文件夹')
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.remoteFiles, (item: FileItem) => {
            ListItem() {
              this.buildFileItem(item)
            }
            .onClick(() => {
              if (item.isDirectory) {
                this.navigateToDirectory(item);
              }
            })
          }, (item: FileItem) => item.path)
        }
        .layoutWeight(1)
        .divider({ 
          strokeWidth: 1, 
          color: $r('sys.color.ohos_id_color_list_separator'),
          startMargin: 48,
          endMargin: 16
        })
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
  }
}
