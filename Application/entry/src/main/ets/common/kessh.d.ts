declare module 'libkessh.so' {
  export function openSession(host: string, port: number, username: string, password: string): number;
  export function closeSession(sessionId: number): void;
  export function setKeepaliveConfig(intervalSeconds: number, attempts: number): void;
  export function sendKeepalive(sessionId: number): boolean;
  export function write(sessionId: number, data: string): void;
  export function read(sessionId: number): string;
  // optional native helpers
  export function executeCommand(sessionId: number, command: string): string;
  export function downloadFile(sessionId: number, remotePath: string): string;
  export function uploadFile(sessionId: number, remotePath: string, content: string): number;
  export function testNative?(): number;
}
