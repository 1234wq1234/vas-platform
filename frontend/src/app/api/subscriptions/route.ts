import { NextResponse } from 'next/server';
import { withConnection, rowsToArray } from '@/lib/oracle';

export async function GET() {
  try {
    const rows = await withConnection(async (conn) => {
      const r = await conn.execute(
        `SELECT sub.subscription_id, sub.subscriber_id, s.msisdn, s.full_name,
                srv.service_id, srv.service_code, srv.service_name,
                sub.status, sub.price_charged, sub.started_at, sub.cancelled_at
         FROM subscriptions sub
         JOIN subscribers s ON s.subscriber_id = sub.subscriber_id
         JOIN services srv ON srv.service_id = sub.service_id
         ORDER BY sub.started_at DESC`
      );
      return rowsToArray(r);
    });
    return NextResponse.json({ success: true, data: rows });
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Hata';
    return NextResponse.json({ success: false, message: msg }, { status: 500 });
  }
}
