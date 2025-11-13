import { WebSocketClient } from '../common/WebSocketClient';
import hilog from '@ohos.hilog';
import { BusinessError } from '@kit.BasicServicesKit';

const LOG_DOMAIN = 0xD15D;
const LOG_TAG = 'WebSocketTestPage';

@Entry
@Component
struct WebSocketTestPage {
  @State connectionStatus: string = 'Disconnected';
  @State messages: string[] = [];
  @State inputMessage: string = '';
  @State isConnected: boolean = false;
  
  private wsClient: WebSocketClient = new WebSocketClient();

  aboutToAppear(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocketTestPage aboutToAppear');
    // Set up WebSocket callbacks
    this.setupWebSocketCallbacks();
  }

  aboutToDisappear(): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocketTestPage aboutToDisappear');
    // Clean up WebSocket connection
    this.disconnect();
  }

  setupWebSocketCallbacks(): void {
    this.wsClient.onMessage((data: string | ArrayBuffer) => {
      const message = typeof data === 'string' ? data : '[Binary Data]';
      this.messages = [...this.messages, `Received: ${message}`];
      hilog.info(LOG_DOMAIN, LOG_TAG, `Message received: ${message}`);
    });

    this.wsClient.onError((error: BusinessError) => {
      this.connectionStatus = `Error: ${error.message}`;
      this.isConnected = false;
      this.messages = [...this.messages, `Error: ${error.message}`];
      hilog.error(LOG_DOMAIN, LOG_TAG, `WebSocket error: ${JSON.stringify(error)}`);
    });

    this.wsClient.onClose((code: number, reason: string) => {
      this.connectionStatus = `Closed: ${code} - ${reason}`;
      this.isConnected = false;
      hilog.info(LOG_DOMAIN, LOG_TAG, `WebSocket closed: ${code} - ${reason}`);
    });
  }

  connect(): void {
    if (this.isConnected) {
      this.addMessage('Already connected');
      return;
    }

    // Example WebSocket server URL - replace with your actual server
    const serverUrl = 'ws://localhost:8080'; // Replace with your WebSocket server URL
    
    this.connectionStatus = 'Connecting...';
    this.addMessage(`Connecting to ${serverUrl}`);

    this.wsClient.connect(serverUrl)
      .then(() => {
        this.connectionStatus = 'Connected';
        this.isConnected = true;
        this.addMessage('Connected successfully');
        hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocket connected successfully');
      })
      .catch((error: Error) => {
        this.connectionStatus = `Connection failed: ${error.message}`;
        this.addMessage(`Connection failed: ${error.message}`);
        hilog.error(LOG_DOMAIN, LOG_TAG, `WebSocket connection failed: ${JSON.stringify(error)}`);
      });
  }

  disconnect(): void {
    if (!this.isConnected) {
      this.addMessage('Not connected');
      return;
    }

    this.wsClient.close()
      .then(() => {
        this.connectionStatus = 'Disconnected';
        this.isConnected = false;
        this.addMessage('Disconnected successfully');
        hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocket disconnected successfully');
      })
      .catch((error: Error) => {
        this.connectionStatus = `Disconnect failed: ${error.message}`;
        this.addMessage(`Disconnect failed: ${error.message}`);
        hilog.error(LOG_DOMAIN, LOG_TAG, `WebSocket disconnect failed: ${JSON.stringify(error)}`);
      });
  }

  sendMessage(): void {
    if (!this.isConnected) {
      this.addMessage('Not connected');
      return;
    }

    if (!this.inputMessage.trim()) {
      this.addMessage('Please enter a message');
      return;
    }

    this.wsClient.send(this.inputMessage)
      .then(() => {
        this.addMessage(`Sent: ${this.inputMessage}`);
        this.inputMessage = '';
        hilog.info(LOG_DOMAIN, LOG_TAG, `Message sent: ${this.inputMessage}`);
      })
      .catch((error: Error) => {
        this.addMessage(`Send failed: ${error.message}`);
        hilog.error(LOG_DOMAIN, LOG_TAG, `Message send failed: ${JSON.stringify(error)}`);
      });
  }

  addMessage(message: string): void {
    this.messages = [...this.messages, message];
  }

  build() {
    Column() {
      Text('WebSocket Test')
        .fontSize(24)
        .margin({ bottom: 20 })
        .fontWeight(FontWeight.Bold)

      Text(`Status: ${this.connectionStatus}`)
        .fontSize(16)
        .margin({ bottom: 20 })
        .fontColor(this.isConnected ? '#00FF00' : '#FF0000')

      Row() {
        Button('Connect')
          .onClick(() => this.connect())
          .margin({ right: 10 })
          .enabled(!this.isConnected)

        Button('Disconnect')
          .onClick(() => this.disconnect())
          .margin({ left: 10 })
          .enabled(this.isConnected)
      }
      .margin({ bottom: 20 })

      Row() {
        TextInput({ placeholder: 'Enter message...', text: $$this.inputMessage })
          .layoutWeight(1)
        
        Button('Send')
          .onClick(() => this.sendMessage())
          .width('25%')
          .margin({ left: '5%' })
          .enabled(this.isConnected)
      }
      .margin({ bottom: 20 })

      Scroll() {
        Column() {
          ForEach(this.messages, (message: string, index: number) => {
            Text(message)
              .fontSize(14)
              .textAlign(TextAlign.Start)
              .width('100%')
              .padding(5)
              .backgroundColor('#f0f0f0')
          }, (item: string) => item)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
    }
    .padding(20)
    .width('100%')
    .height('100%')
  }
}