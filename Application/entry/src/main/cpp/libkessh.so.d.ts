/**
 * Native SSH and network helper module interface
 */
export const openSession: (host: string, port: number, user: string, pass: string) => number;
export const closeSession: (sessionId: number) => void;
export const setKeepaliveConfig: (intervalSeconds: number, attempts: number) => void;
export const sendKeepalive: (sessionId: number) => boolean;
export const write: (sessionId: number, data: string) => void;
export const read: (sessionId: number) => string;
export const executeCommand: (sessionId: number, command: string) => string;
export const downloadFile: (sessionId: number, remotePath: string) => string;
export const uploadFile: (sessionId: number, remotePath: string, content: string) => number;
export const testNative: () => number;
export const pingHost: (host: string, count?: number) => string;
export const testPort: (host: string, port: number, timeout?: number) => string;
