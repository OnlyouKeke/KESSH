import kessh from 'libkessh.so';

export class SSHEngine {
    static openSession(host: string, port: number, user: string, pass: string): number {
        return kessh.openSession(host, port, user, pass);
    }

    static closeSession(sessionId: number): void {
        kessh.closeSession(sessionId);
    }

    static write(sessionId: number, data: string): void {
        kessh.write(sessionId, data);
    }

    static read(sessionId: number): string {
        return kessh.read(sessionId);
    }
}