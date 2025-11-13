import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';
import util from '@ohos.util';

const LOG_DOMAIN = 0xD15E;
const LOG_TAG = 'WebSocketSSHClient';

export interface SSHConnectionConfig {
  host: string;
  port: number;
  username: string;
  password: string;
  wsServerUrl: string; // WebSocket proxy server URL
}

export class WebSocketSSHClient {
  private ws: webSocket.WebSocket | undefined = undefined;
  private isConnected: boolean = false;
  private sshConnected: boolean = false;
  private dataCallback: ((data: string) => void) | undefined;
  private errorCallback: ((error: string) => void) | undefined;
  private connectionCallback: ((connected: boolean) => void) | undefined;
  private connectResolve: ((value: void | PromiseLike<void>) => void) | undefined;
  private connectReject: ((reason?: Error) => void) | undefined;
  private textEncoder: util.TextEncoder = new util.TextEncoder();
  private textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');

  constructor() {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocketSSHClient constructor called');
  }

  /**
   * Connect to SSH server via WebSocket proxy
   */
  connect(config: SSHConnectionConfig): Promise<void> {
    return new Promise((resolve, reject) => {
      hilog.info(LOG_DOMAIN, LOG_TAG, `Connecting to WebSocket proxy: ${config.wsServerUrl}`);
      
      try {
        this.ws = webSocket.createWebSocket();
        this.setupEventListeners(config, resolve, reject);
        
        this.ws.connect(config.wsServerUrl, {}, (err: BusinessError, value: boolean) => {
          if (err) {
            hilog.error(LOG_DOMAIN, LOG_TAG, `WebSocket connection failed: ${JSON.stringify(err)}`);
            reject(new Error(`WebSocket connection failed: ${err.message}`));
            return;
          }
          hilog.info(LOG_DOMAIN, LOG_TAG, `WebSocket connection initiated: ${value}`);
        });
      } catch (error) {
        hilog.error(LOG_DOMAIN, LOG_TAG, `Exception during connection: ${JSON.stringify(error)}`);
        reject(new Error(`Connection exception: ${error}`));
      }
    });
  }

  /**
   * Set up WebSocket event listeners
   */
  private setupEventListeners(
    config: SSHConnectionConfig, 
    resolve: (value: void | PromiseLike<void>) => void, 
    reject: (reason?: Error) => void
  ): void {
    if (!this.ws) {
      reject(new Error('WebSocket instance is undefined'));
      return;
    }

    // Handle WebSocket connection open
    this.ws.on('open', (err: BusinessError, value: Object) => {
      if (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, `WebSocket open error: ${JSON.stringify(err)}`);
        reject(new Error(`WebSocket open error: ${err.message}`));
        return;
      }
      
      hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocket connection established');
      this.isConnected = true;
      
      // Send SSH connection request
      this.sendSSHConnect(config, resolve, reject);
    });

    // Handle incoming messages
    this.ws.on('message', (error: BusinessError, value: string | ArrayBuffer) => {
      if (error) {
        hilog.error(LOG_DOMAIN, LOG_TAG, `Message error: ${JSON.stringify(error)}`);
        if (this.errorCallback) {
          this.errorCallback(error.message);
        }
        return;
      }

      this.handleMessage(value);
    });

    // Handle errors
    this.ws.on('error', (err: BusinessError) => {
      hilog.error(LOG_DOMAIN, LOG_TAG, `WebSocket error: ${JSON.stringify(err)}`);
      this.isConnected = false;
      this.sshConnected = false;
      if (this.errorCallback) {
        this.errorCallback(err.message);
      }
    });

    // Handle connection close
    this.ws.on('close', (err: BusinessError, value: webSocket.CloseResult) => {
      hilog.info(LOG_DOMAIN, LOG_TAG, `WebSocket closed: ${value.code} - ${value.reason}`);
      this.isConnected = false;
      this.sshConnected = false;
      if (this.connectionCallback) {
        this.connectionCallback(false);
      }
    });
  }

  /**
   * Send SSH connection request to proxy
   */
  private sendSSHConnect(
    config: SSHConnectionConfig,
    resolve: (value: void | PromiseLike<void>) => void,
    reject: (reason?: Error) => void
  ): void {
    // Save resolve/reject for later use when SSH connection is established
    this.connectResolve = resolve;
    this.connectReject = reject;
    
    const connectMsg = JSON.stringify({
      type: 'connect',
      host: config.host,
      port: config.port,
      username: config.username,
      password: config.password
    });

    hilog.info(LOG_DOMAIN, LOG_TAG, `Sending SSH connection request to ${config.host}:${config.port}`);
    
    this.ws?.send(connectMsg, (err: BusinessError, value: boolean) => {
      if (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, `Failed to send SSH connect: ${JSON.stringify(err)}`);
        reject(new Error(`Failed to send SSH connect: ${err.message}`));
        this.connectResolve = undefined;
        this.connectReject = undefined;
      }
    });
  }

  /**
   * Handle incoming messages from WebSocket
   */
  private handleMessage(value: string | ArrayBuffer): void {
    try {
      const messageStr = typeof value === 'string' ? value : this.arrayBufferToString(value);
      const message = JSON.parse(messageStr) as Record<string, string>;

      hilog.info(LOG_DOMAIN, LOG_TAG, `Received message type: ${message.type}`);

      switch (message.type) {
        case 'connected':
          hilog.info(LOG_DOMAIN, LOG_TAG, 'SSH connection established');
          this.sshConnected = true;
          
          // Resolve the connect promise
          if (this.connectResolve) {
            this.connectResolve();
            this.connectResolve = undefined;
            this.connectReject = undefined;
          }
          
          if (this.connectionCallback) {
            this.connectionCallback(true);
          }
          break;

        case 'data':
          // Decode base64 data
          const decodedData = this.base64Decode(message.data);
          hilog.debug(LOG_DOMAIN, LOG_TAG, `SSH data received: ${decodedData.length} bytes`);
          if (this.dataCallback) {
            this.dataCallback(decodedData);
          }
          break;

        case 'error':
          hilog.error(LOG_DOMAIN, LOG_TAG, `SSH error: ${message.message}`);
          
          // Reject the connect promise if still pending
          if (this.connectReject) {
            this.connectReject(new Error(message.message));
            this.connectResolve = undefined;
            this.connectReject = undefined;
          }
          
          if (this.errorCallback) {
            this.errorCallback(message.message);
          }
          break;

        case 'disconnected':
        case 'closed':
          hilog.info(LOG_DOMAIN, LOG_TAG, 'SSH connection closed');
          this.sshConnected = false;
          if (this.connectionCallback) {
            this.connectionCallback(false);
          }
          break;

        default:
          hilog.warn(LOG_DOMAIN, LOG_TAG, `Unknown message type: ${message.type}`);
      }
    } catch (error) {
      hilog.error(LOG_DOMAIN, LOG_TAG, `Failed to parse message: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Send input to SSH session
   */
  sendInput(data: string): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.ws || !this.isConnected) {
        reject(new Error('WebSocket not connected'));
        return;
      }

      if (!this.sshConnected) {
        reject(new Error('SSH not connected'));
        return;
      }

      const encodedData = this.base64Encode(data);
      const inputMsg = JSON.stringify({
        type: 'input',
        data: encodedData
      });

      hilog.debug(LOG_DOMAIN, LOG_TAG, `Sending SSH input: ${data.length} bytes`);

      this.ws.send(inputMsg, (err: BusinessError, value: boolean) => {
        if (err) {
          hilog.error(LOG_DOMAIN, LOG_TAG, `Failed to send input: ${JSON.stringify(err)}`);
          reject(new Error(`Failed to send input: ${err.message}`));
          return;
        }
        resolve();
      });
    });
  }

  /**
   * Disconnect from SSH
   */
  disconnect(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.ws) {
        resolve();
        return;
      }

      if (this.sshConnected) {
        const disconnectMsg = JSON.stringify({ type: 'disconnect' });
        this.ws.send(disconnectMsg, (err: BusinessError) => {
          if (err) {
            hilog.warn(LOG_DOMAIN, LOG_TAG, `Failed to send disconnect: ${JSON.stringify(err)}`);
          }
        });
      }

      this.ws.close((err: BusinessError) => {
        if (err) {
          hilog.error(LOG_DOMAIN, LOG_TAG, `Failed to close WebSocket: ${JSON.stringify(err)}`);
          reject(new Error(`Failed to close WebSocket: ${err.message}`));
          return;
        }
        
        hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocket closed successfully');
        this.isConnected = false;
        this.sshConnected = false;
        resolve();
      });
    });
  }

  /**
   * Set data callback
   */
  onData(callback: (data: string) => void): void {
    this.dataCallback = callback;
  }

  /**
   * Set error callback
   */
  onError(callback: (error: string) => void): void {
    this.errorCallback = callback;
  }

  /**
   * Set connection status callback
   */
  onConnectionChange(callback: (connected: boolean) => void): void {
    this.connectionCallback = callback;
  }

  /**
   * Check if connected
   */
  get connected(): boolean {
    return this.isConnected && this.sshConnected;
  }

  /**
   * Base64 encode
   */
  private base64Encode(str: string): string {
    const encoded = this.textEncoder.encodeInto(str);
    const buffer = encoded.buffer as ArrayBuffer;
    return this.arrayBufferToBase64(buffer);
  }

  /**
   * Base64 decode
   */
  private base64Decode(base64: string): string {
    const buffer = this.base64ToArrayBuffer(base64);
    const result = this.textDecoder.decodeWithStream(new Uint8Array(buffer), { stream: false });
    return result;
  }

  /**
   * ArrayBuffer to string
   */
  private arrayBufferToString(buffer: ArrayBuffer): string {
    const result = this.textDecoder.decodeWithStream(new Uint8Array(buffer), { stream: false });
    return result;
  }

  /**
   * ArrayBuffer to base64
   */
  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return this.btoa(binary);
  }

  /**
   * Base64 to ArrayBuffer
   */
  private base64ToArrayBuffer(base64: string): ArrayBuffer {
    const binary = this.atob(base64);
    const buffer = new ArrayBuffer(binary.length);
    const bytes = new Uint8Array(buffer);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return buffer;
  }

  /**
   * Simple btoa implementation
   */
  private btoa(str: string): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';
    let i = 0;
    
    while (i < str.length) {
      const a = str.charCodeAt(i++);
      const b = i < str.length ? str.charCodeAt(i++) : 0;
      const c = i < str.length ? str.charCodeAt(i++) : 0;
      
      const bitmap = (a << 16) | (b << 8) | c;
      
      const charMap = chars.split('');
      result += charMap[(bitmap >> 18) & 63];
      result += charMap[(bitmap >> 12) & 63];
      result += i - 2 < str.length ? charMap[(bitmap >> 6) & 63] : '=';
      result += i - 1 < str.length ? charMap[bitmap & 63] : '=';
    }
    
    return result;
  }

  /**
   * Simple atob implementation
   */
  private atob(str: string): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    str = str.replace(/=+$/, '');
    let result = '';
    
    for (let i = 0; i < str.length;) {
      const charMap = chars.split('');
      const a = charMap.indexOf(str[i++]);
      const b = charMap.indexOf(str[i++]);
      const c = i < str.length ? charMap.indexOf(str[i++]) : 64;
      const d = i < str.length ? charMap.indexOf(str[i++]) : 64;
      
      const bitmap = (a << 18) | (b << 12) | (c << 6) | d;
      
      result += String.fromCharCode((bitmap >> 16) & 255);
      if (c !== 64) result += String.fromCharCode((bitmap >> 8) & 255);
      if (d !== 64) result += String.fromCharCode(bitmap & 255);
    }
    
    return result;
  }
}