import { NextRequest, NextResponse } from 'next/server';
import { withConnection, rowsToArray } from '@/lib/oracle';
import type { OracleConnection } from '@/lib/oracle';
import {
  AUDIT_SELECT_BASE,
  AUDIT_SELECT_EXTENDED,
  enrichAuditRows,
} from '@/lib/audit-map';
import { formatConnectionError } from '@/lib/messages';

let useExtendedAuditColumns: boolean | null = null;

async function resolveAuditSelect(conn: OracleConnection): Promise<string> {
  if (useExtendedAuditColumns === true) return AUDIT_SELECT_EXTENDED;
  if (useExtendedAuditColumns === false) return AUDIT_SELECT_BASE;

  try {
    await conn.execute(
      `SELECT log_level, response_code FROM audit_logs WHERE ROWNUM = 1`
    );
    useExtendedAuditColumns = true;
    return AUDIT_SELECT_EXTENDED;
  } catch (e) {
    const msg = e instanceof Error ? e.message : '';
    if (msg.includes('ORA-00904')) {
      useExtendedAuditColumns = false;
      return AUDIT_SELECT_BASE;
    }
    throw e;
  }
}

async function fetchAuditRows(
  conn: OracleConnection,
  whereSql: string,
  binds: Record<string, unknown>
) {
  const select = await resolveAuditSelect(conn);
  const r = await conn.execute(
    `SELECT * FROM (
       ${select}
       ${whereSql}
       ORDER BY created_at DESC
     ) WHERE ROWNUM <= :lim`,
    { ...binds, lim: binds.lim }
  );
  return enrichAuditRows(rowsToArray(r) as Record<string, unknown>[]);
}

export async function GET(req: NextRequest) {
  const limit = Math.min(Number(req.nextUrl.searchParams.get('limit') || 300), 500);
  const start = req.nextUrl.searchParams.get('start');
  const end = req.nextUrl.searchParams.get('end');
  const todayOnly = req.nextUrl.searchParams.get('today') === '1';

  try {
    const rows = await withConnection(async (conn) => {
      if (todayOnly) {
        return fetchAuditRows(
          conn,
          'WHERE TRUNC(created_at) = TRUNC(SYSDATE)',
          { lim: limit }
        );
      }

      if (start && end) {
        return fetchAuditRows(
          conn,
          `WHERE TRUNC(created_at) >= TO_DATE(:start_date, 'YYYY-MM-DD')
             AND TRUNC(created_at) <= TO_DATE(:end_date, 'YYYY-MM-DD')`,
          { start_date: start, end_date: end, lim: limit }
        );
      }

      return fetchAuditRows(conn, '', { lim: limit });
    });
    return NextResponse.json({ success: true, data: rows });
  } catch (e) {
    const raw = e instanceof Error ? e.message : 'Hata';
    return NextResponse.json(
      { success: false, message: formatConnectionError(raw) },
      { status: 500 }
    );
  }
}
