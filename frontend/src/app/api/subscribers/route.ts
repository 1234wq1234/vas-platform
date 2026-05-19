import { NextResponse } from 'next/server';
import { withConnection, rowsToArray } from '@/lib/oracle';

export async function GET() {
  try {
    const rows = await withConnection(async (conn) => {
      const r = await conn.execute(
        `SELECT subscriber_id, msisdn, full_name, balance, status, created_at
         FROM subscribers ORDER BY subscriber_id`
      );
      return rowsToArray(r);
    });
    return NextResponse.json({ success: true, data: rows });
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Hata';
    return NextResponse.json({ success: false, message: msg }, { status: 500 });
  }
}
