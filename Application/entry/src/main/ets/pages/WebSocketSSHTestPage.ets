import { WebSocketSSHClient, SSHConnectionConfig } from '../common/WebSocketSSHClient';
import hilog from '@ohos.hilog';

const LOG_DOMAIN = 0xD15F;
const LOG_TAG = 'WebSocketSSHTestPage';

@Entry
@Component
struct WebSocketSSHTestPage {
  @State connectionStatus: string = 'Disconnected';
  @State terminalOutput: string = '';
  @State inputCommand: string = '';
  @State isConnected: boolean = false;
  
  @State sshHost: string = '192.168.1.100';
  @State sshPort: string = '22';
  @State sshUsername: string = 'root';
  @State sshPassword: string = '';
  @State wsProxyUrl: string = 'ws://localhost:8080';
  
  private sshClient: WebSocketSSHClient = new WebSocketSSHClient();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocketSSHTestPage aboutToAppear');
    this.setupSSHCallbacks();
  }

  aboutToDisappear(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocketSSHTestPage aboutToDisappear');
    this.disconnect();
  }

  setupSSHCallbacks(): void {
    this.sshClient.onData((data: string) => {
      this.terminalOutput += data;
      hilog.debug(LOG_DOMAIN, LOG_TAG, `Received data: ${data.length} bytes`);
      
      // Auto scroll to bottom
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 100);
    });

    this.sshClient.onError((error: string) => {
      this.connectionStatus = `Error: ${error}`;
      this.terminalOutput += `\n[ERROR] ${error}\n`;
      hilog.error(LOG_DOMAIN, LOG_TAG, `SSH error: ${error}`);
    });

    this.sshClient.onConnectionChange((connected: boolean) => {
      this.isConnected = connected;
      this.connectionStatus = connected ? 'Connected' : 'Disconnected';
      if (connected) {
        this.terminalOutput += '\n[INFO] SSH connection established\n';
      } else {
        this.terminalOutput += '\n[INFO] SSH connection closed\n';
      }
    });
  }

  connect(): void {
    if (this.isConnected) {
      this.terminalOutput += '\n[WARN] Already connected\n';
      return;
    }

    const port = parseInt(this.sshPort);
    if (isNaN(port) || port < 1 || port > 65535) {
      this.terminalOutput += '\n[ERROR] Invalid port number\n';
      return;
    }

    const config: SSHConnectionConfig = {
      host: this.sshHost,
      port: port,
      username: this.sshUsername,
      password: this.sshPassword,
      wsServerUrl: this.wsProxyUrl
    };
    
    this.connectionStatus = 'Connecting...';
    this.terminalOutput += `\n[INFO] Connecting to ${config.host}:${config.port} via ${config.wsServerUrl}\n`;

    this.sshClient.connect(config)
      .then(() => {
        hilog.info(LOG_DOMAIN, LOG_TAG, 'SSH connection successful');
      })
      .catch((error: Error) => {
        this.connectionStatus = `Connection failed: ${error.message}`;
        this.terminalOutput += `\n[ERROR] Connection failed: ${error.message}\n`;
        hilog.error(LOG_DOMAIN, LOG_TAG, `Connection failed: ${JSON.stringify(error)}`);
      });
  }

  disconnect(): void {
    if (!this.isConnected) {
      this.terminalOutput += '\n[WARN] Not connected\n';
      return;
    }

    this.sshClient.disconnect()
      .then(() => {
        this.connectionStatus = 'Disconnected';
        this.isConnected = false;
        this.terminalOutput += '\n[INFO] Disconnected successfully\n';
        hilog.info(LOG_DOMAIN, LOG_TAG, 'Disconnected successfully');
      })
      .catch((error: Error) => {
        this.terminalOutput += `\n[ERROR] Disconnect failed: ${error.message}\n`;
        hilog.error(LOG_DOMAIN, LOG_TAG, `Disconnect failed: ${JSON.stringify(error)}`);
      });
  }

  sendCommand(): void {
    if (!this.isConnected) {
      this.terminalOutput += '\n[WARN] Not connected\n';
      return;
    }

    if (!this.inputCommand.trim()) {
      return;
    }

    const command = this.inputCommand + '\n';
    this.terminalOutput += `$ ${this.inputCommand}\n`;
    
    this.sshClient.sendInput(command)
      .then(() => {
        this.inputCommand = '';
        hilog.debug(LOG_DOMAIN, LOG_TAG, 'Command sent successfully');
      })
      .catch((error: Error) => {
        this.terminalOutput += `\n[ERROR] Send failed: ${error.message}\n`;
        hilog.error(LOG_DOMAIN, LOG_TAG, `Send failed: ${JSON.stringify(error)}`);
      });
  }

  clearTerminal(): void {
    this.terminalOutput = '';
  }

  build() {
    Column() {
      Text('WebSocket SSH Terminal')
        .fontSize(20)
        .margin({ bottom: 10 })
        .fontWeight(FontWeight.Bold)

      // Connection info section
      Column() {
        Row() {
          Text('Proxy:')
            .width(80)
          TextInput({ placeholder: 'ws://localhost:8080', text: $$this.wsProxyUrl })
            .layoutWeight(1)
            .enabled(!this.isConnected)
        }
        .width('100%')
        .margin({ bottom: 5 })

        Row() {
          Text('Host:')
            .width(80)
          TextInput({ placeholder: 'SSH Host', text: $$this.sshHost })
            .layoutWeight(1)
            .enabled(!this.isConnected)
          
          Text('Port:')
            .width(50)
            .margin({ left: 10 })
          TextInput({ placeholder: '22', text: $$this.sshPort })
            .width(80)
            .enabled(!this.isConnected)
        }
        .width('100%')
        .margin({ bottom: 5 })

        Row() {
          Text('User:')
            .width(80)
          TextInput({ placeholder: 'Username', text: $$this.sshUsername })
            .layoutWeight(1)
            .enabled(!this.isConnected)
        }
        .width('100%')
        .margin({ bottom: 5 })

        Row() {
          Text('Password:')
            .width(80)
          TextInput({ placeholder: 'Password', text: $$this.sshPassword })
            .type(InputType.Password)
            .layoutWeight(1)
            .enabled(!this.isConnected)
        }
        .width('100%')
        .margin({ bottom: 10 })
      }
      .backgroundColor('#f5f5f5')
      .padding(10)
      .borderRadius(5)
      .margin({ bottom: 10 })

      // Status and control buttons
      Row() {
        Text(`Status: ${this.connectionStatus}`)
          .fontSize(14)
          .layoutWeight(1)
          .fontColor(this.isConnected ? '#00AA00' : '#FF0000')

        Button('Connect')
          .onClick(() => this.connect())
          .margin({ right: 5 })
          .enabled(!this.isConnected)
          .fontSize(14)

        Button('Disconnect')
          .onClick(() => this.disconnect())
          .enabled(this.isConnected)
          .fontSize(14)
      }
      .width('100%')
      .margin({ bottom: 10 })

      // Terminal output
      Scroll(this.scroller) {
        Text(this.terminalOutput)
          .fontSize(12)
          .fontFamily('monospace')
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .backgroundColor('#000000')
      .padding(10)
      .width('100%')
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.None)

      // Input section
      Row() {
        TextInput({ placeholder: 'Enter command...', text: $$this.inputCommand })
          .layoutWeight(1)
          .backgroundColor('#FFFFFF')
          .onSubmit(() => this.sendCommand())
          .enabled(this.isConnected)
        
        Button('Send')
          .onClick(() => this.sendCommand())
          .margin({ left: 5 })
          .enabled(this.isConnected)
          .fontSize(14)

        Button('Clear')
          .onClick(() => this.clearTerminal())
          .margin({ left: 5 })
          .fontSize(14)
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .padding(15)
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}