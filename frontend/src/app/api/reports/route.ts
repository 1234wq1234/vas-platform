import { NextRequest, NextResponse } from 'next/server';
import { withConnection, OraBind, parseJsonClob } from '@/lib/oracle';
import { formatConnectionError } from '@/lib/messages';

export async function GET(req: NextRequest) {
  const type = req.nextUrl.searchParams.get('type') || 'revenue';
  const period = req.nextUrl.searchParams.get('period') || '24H';
  const start = req.nextUrl.searchParams.get('start');
  const end = req.nextUrl.searchParams.get('end');

  try {
    if (type === 'best-selling') {
      const rows = await withConnection(async (conn) => {
        const r = await conn.execute(
          `BEGIN pkg_vas_reports.report_best_selling(:p_json); END;`,
          { p_json: OraBind.outJson() }
        );
        return await parseJsonClob(r.outBinds?.p_json);
      });
      return NextResponse.json({ success: true, data: rows });
    }

    if (type === 'active-subscriptions') {
      const result = await withConnection(async (conn) => {
        const r = await conn.execute(
          `BEGIN
             pkg_vas_reports.report_active_subscriptions(:total, :p_json);
           END;`,
          {
            total: OraBind.outNumber(),
            p_json: OraBind.outJson(),
          }
        );
        const binds = r.outBinds as { total: number; p_json: unknown };
        return { total: binds.total, data: await parseJsonClob(binds.p_json) };
      });
      return NextResponse.json({ success: true, ...result });
    }

    if (type === 'revenue') {
      const result = await withConnection(async (conn) => {
        const r = await conn.execute(
          `BEGIN
             pkg_vas_reports.report_revenue(:period, :total, :sub_rev, :ot_rev);
           END;`,
          {
            period,
            total: OraBind.outNumber(),
            sub_rev: OraBind.outNumber(),
            ot_rev: OraBind.outNumber(),
          }
        );
        return r.outBinds as { total: number; sub_rev: number; ot_rev: number };
      });
      return NextResponse.json({
        success: true,
        period,
        total: result.total,
        subscriptionRevenue: result.sub_rev,
        oneTimeRevenue: result.ot_rev,
      });
    }

    if (type === 'sales-performance' && start && end) {
      const rows = await withConnection(async (conn) => {
        const r = await conn.execute(
          `BEGIN
             pkg_vas_reports.report_sales_performance(
               TO_DATE(:start, 'YYYY-MM-DD'),
               TO_DATE(:end, 'YYYY-MM-DD'),
               :p_json
             );
           END;`,
          {
            start,
            end,
            p_json: OraBind.outJson(),
          }
        );
        return await parseJsonClob(r.outBinds?.p_json);
      });
      return NextResponse.json({ success: true, data: rows });
    }

    return NextResponse.json({ success: false, message: 'Gecersiz rapor tipi' }, { status: 400 });
  } catch (e) {
    const raw = e instanceof Error ? e.message : 'Hata';
    const friendly =
      raw.includes('is not valid JSON') || raw.includes('[object Object]')
        ? 'Rapor verisi okunamadi. Oracle rapor paketini yeniden derleyin.'
        : formatConnectionError(raw);
    return NextResponse.json({ success: false, message: friendly }, { status: 500 });
  }
}
