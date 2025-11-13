import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';

const LOG_DOMAIN = 0xD15C;
const LOG_TAG = 'WebSocketClient';

export class WebSocketClient {
  private ws: webSocket.WebSocket | undefined = undefined;
  private isConnected: boolean = false;
  private messageCallback: ((data: string | ArrayBuffer) => void) | undefined;
  private errorCallback: ((error: BusinessError) => void) | undefined;
  private closeCallback: ((code: number, reason: string) => void) | undefined;

  constructor() {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocketClient constructor called');
  }

  /**
   * Connect to WebSocket server
   * @param url WebSocket server URL (e.g., 'ws://localhost:8080')
   * @param headers Optional headers
   * @returns Promise that resolves when connection is established
   */
  connect(url: string, headers?: Record<string, string>): Promise<void> {
    return new Promise((resolve, reject) => {
      hilog.info(LOG_DOMAIN, LOG_TAG, `Connecting to WebSocket server: ${url}`);
      
      try {
        // Create WebSocket instance
        this.ws = webSocket.createWebSocket();
        
        // Set up event listeners
        this.setupEventListeners(resolve, reject);
        
        // Connect to server
        const emptyHeader: Record<string, string> = {};
        const options: webSocket.WebSocketRequestOptions = {
          header: headers || emptyHeader
        };
        
        this.ws.connect(url, options, (err: BusinessError, value: boolean) => {
          if (err) {
            hilog.error(LOG_DOMAIN, LOG_TAG, `Connection failed: ${JSON.stringify(err)}`);
            reject(new Error(`Connection failed: ${err.message}`));
            return;
          }
          
          hilog.info(LOG_DOMAIN, LOG_TAG, `Connection request sent successfully: ${value}`);
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
  private setupEventListeners(resolve: (value: void | PromiseLike<void>) => void, reject: (reason?: Error) => void): void {
    if (!this.ws) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'WebSocket instance is undefined');
      reject(new Error('WebSocket instance is undefined'));
      return;
    }

    // Handle successful connection
    this.ws.on('open', (err: BusinessError, value: Object) => {
      if (err) {
        hilog.error(LOG_DOMAIN, LOG_TAG, `Connection error: ${JSON.stringify(err)}`);
        reject(new Error(`Connection error: ${err.message}`));
        return;
      }
      
      hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocket connection established');
      this.isConnected = true;
      resolve();
    });

    // Handle received messages
    this.ws.on('message', (error: BusinessError, value: string | ArrayBuffer) => {
      if (error) {
        hilog.error(LOG_DOMAIN, LOG_TAG, `Message error: ${JSON.stringify(error)}`);
        if (this.errorCallback) {
          this.errorCallback(error);
        }
        return;
      }

      hilog.info(LOG_DOMAIN, LOG_TAG, `Message received: ${typeof value === 'string' ? value : '[ArrayBuffer]'}`);
      if (this.messageCallback) {
        this.messageCallback(value);
      }
    });

    // Handle errors
    this.ws.on('error', (err: BusinessError) => {
      hilog.error(LOG_DOMAIN, LOG_TAG, `WebSocket error: ${JSON.stringify(err)}`);
      this.isConnected = false;
      if (this.errorCallback) {
        this.errorCallback(err);
      }
    });

    // Handle connection close
    this.ws.on('close', (err: BusinessError, value: webSocket.CloseResult) => {
      hilog.info(LOG_DOMAIN, LOG_TAG, `WebSocket connection closed: code=${value.code}, reason=${value.reason}`);
      this.isConnected = false;
      if (this.closeCallback) {
        this.closeCallback(value.code, value.reason);
      }
    });
  }

  /**
   * Send message through WebSocket
   * @param data Message data to send
   * @returns Promise that resolves when message is sent
   */
  send(data: string | ArrayBuffer): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.ws) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'WebSocket not initialized');
        reject(new Error('WebSocket not initialized'));
        return;
      }

      if (!this.isConnected) {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'WebSocket not connected');
        reject(new Error('WebSocket not connected'));
        return;
      }

      hilog.info(LOG_DOMAIN, LOG_TAG, `Sending message: ${typeof data === 'string' ? data : '[ArrayBuffer]'}`);
      
      this.ws.send(data, (err: BusinessError, value: boolean) => {
        if (err) {
          hilog.error(LOG_DOMAIN, LOG_TAG, `Send failed: ${JSON.stringify(err)}`);
          reject(new Error(`Send failed: ${err.message}`));
          return;
        }
        
        hilog.info(LOG_DOMAIN, LOG_TAG, `Message sent successfully: ${value}`);
        resolve();
      });
    });
  }

  /**
   * Close WebSocket connection
   * @returns Promise that resolves when connection is closed
   */
  close(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (!this.ws) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'WebSocket not initialized, nothing to close');
        resolve();
        return;
      }

      hilog.info(LOG_DOMAIN, LOG_TAG, 'Closing WebSocket connection');
      
      this.ws.close((err: BusinessError) => {
        if (err) {
          hilog.error(LOG_DOMAIN, LOG_TAG, `Close failed: ${JSON.stringify(err)}`);
          reject(new Error(`Close failed: ${err.message}`));
          return;
        }
        
        hilog.info(LOG_DOMAIN, LOG_TAG, 'WebSocket connection closed successfully');
        this.isConnected = false;
        resolve();
      });
    });
  }

  /**
   * Check if WebSocket is connected
   * @returns true if connected, false otherwise
   */
  get connected(): boolean {
    return this.isConnected;
  }

  /**
   * Set message callback
   * @param callback Function to call when message is received
   */
  onMessage(callback: (data: string | ArrayBuffer) => void): void {
    this.messageCallback = callback;
  }

  /**
   * Set error callback
   * @param callback Function to call when error occurs
   */
  onError(callback: (error: BusinessError) => void): void {
    this.errorCallback = callback;
  }

  /**
   * Set close callback
   * @param callback Function to call when connection is closed
   */
  onClose(callback: (code: number, reason: string) => void): void {
    this.closeCallback = callback;
  }
}