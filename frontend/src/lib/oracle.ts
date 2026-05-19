import * as oracledb from 'oracledb';

const ora = oracledb as typeof oracledb & {
  outFormat: number;
  fetchAsString: number[];
};
ora.outFormat = ora.OUT_FORMAT_OBJECT;
ora.fetchAsString = [ora.DATE, ora.CLOB];

if (process.env.ORACLE_TNS_ADMIN) {
  process.env.TNS_ADMIN = process.env.ORACLE_TNS_ADMIN;
}

let pool: oracledb.Pool | null = null;

export type OracleConnection = oracledb.Connection;

export const OraBind = {
  outNumber: () => ({ dir: oracledb.BIND_OUT, type: oracledb.NUMBER }),
  outString: (maxSize: number) => ({
    dir: oracledb.BIND_OUT,
    type: oracledb.STRING,
    maxSize,
  }),
 
  outJson: () => ({
    dir: oracledb.BIND_OUT,
    type: oracledb.STRING,
    maxSize: 4000000,
  }),
} as const;

function normalizeRow(row: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, val] of Object.entries(row)) {
    out[key.toUpperCase()] = val;
  }
  return out;
}

function parseJsonText(text: string): Record<string, unknown>[] {
  const trimmed = text.trim();
  if (!trimmed || trimmed === '[]') return [];
  const parsed = JSON.parse(trimmed) as unknown;
  if (!Array.isArray(parsed)) return [];
  return parsed.map((row) => normalizeRow(row as Record<string, unknown>));
}

type LobLike = {
  getData?: () => Promise<string>;
  close?: () => Promise<void>;
};

async function readLobValue(value: LobLike): Promise<string> {
  if (typeof value.getData !== 'function') {
    throw new Error('Gecersiz CLOB nesnesi');
  }
  try {
    return await value.getData();
  } finally {
    if (typeof value.close === 'function') {
      await value.close();
    }
  }
}


export async function parseJsonClob(value: unknown): Promise<Record<string, unknown>[]> {
  if (value == null) return [];

  if (Array.isArray(value)) {
    return value.map((row) => normalizeRow(row as Record<string, unknown>));
  }

  if (typeof value === 'string') {
    return parseJsonText(value);
  }

  if (typeof value === 'object') {
    const lob = value as LobLike;
    if (typeof lob.getData === 'function') {
      const text = await readLobValue(lob);
      return parseJsonText(text);
    }
  }

  return [];
}

export async function getPool(): Promise<oracledb.Pool> {
  if (!pool) {
    const connectString = process.env.ORACLE_CONNECT_STRING;
    if (!connectString) {
      throw new Error('ORACLE_CONNECT_STRING .env dosyasinda tanimli degil.');
    }
    pool = await oracledb.createPool({
      user: process.env.ORACLE_USER,
      password: process.env.ORACLE_PASSWORD,
      connectString,
      poolMin: 1,
      poolMax: 5,
    });
  }
  return pool;
}

export async function withConnection<T>(
  fn: (conn: OracleConnection) => Promise<T>
): Promise<T> {
  const p = await getPool();
  const conn = await p.getConnection();
  try {
    return await fn(conn);
  } finally {
    await conn.close();
  }
}

export function rowsToArray<T>(result: oracledb.Result<T>): T[] {
  return (result.rows as T[]) ?? [];
}
