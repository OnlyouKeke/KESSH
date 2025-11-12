/**
 * Native SSH module interface
 */
export const openSession: (host: string, port: number, user: string, pass: string) => number;
export const closeSession: (sessionId: number) => void;
export const write: (sessionId: number, data: string) => void;
export const read: (sessionId: number) => string;
