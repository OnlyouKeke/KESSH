declare module 'kessh' {
  export function openSession(host: string, port: number, username: string, password: string): number;
  export function closeSession(sessionId: number): void;
  export function write(sessionId: number, data: string): void;
  export function read(sessionId: number): string;
}