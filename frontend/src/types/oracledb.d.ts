declare module 'oracledb' {
  export const BIND_OUT: number;
  export const BIND_IN: number;
  export const NUMBER: number;
  export const STRING: number;
  export const CLOB: number;
  export const OUT_FORMAT_OBJECT: number;
  export const DATE: number;

  export interface Pool {
    getConnection(): Promise<Connection>;
    close(drainTime?: number): Promise<void>;
  }

  export interface Connection {
    execute<T = unknown>(
      sql: string,
      binds?: Record<string, unknown>,
      options?: Record<string, unknown>
    ): Promise<Result<T>>;
    commit(): Promise<void>;
    close(): Promise<void>;
  }

  export interface Result<T = unknown> {
    rows?: T[];
    outBinds?: Record<string, unknown>;
  }

  export function createPool(config: {
    user?: string;
    password?: string;
    connectString?: string;
    poolMin?: number;
    poolMax?: number;
  }): Promise<Pool>;

  var outFormat: number;
  var fetchAsString: number[];
}
