import { NextRequest, NextResponse } from 'next/server';
import { withConnection, OraBind } from '@/lib/oracle';
import { getClientIp } from '@/lib/client-ip';
import { patchLatestAuditLog } from '@/lib/audit-patch';

export async function POST(req: NextRequest) {
  try {
    const { subscriberId, serviceId, performedBy } = await req.json();
    const clientIp = getClientIp(req);

    const result = await withConnection(async (conn) => {
      const r = await conn.execute(
        `BEGIN
           pkg_vas_core.purchase_one_time(
             :sub_id, :svc_id, :performed_by,
             :purchase_id, :result_code, :result_msg
           );
         END;`,
        {
          sub_id: Number(subscriberId),
          svc_id: Number(serviceId),
          performed_by: performedBy || 'web',
          purchase_id: OraBind.outNumber(),
          result_code: OraBind.outString(50),
          result_msg: OraBind.outString(1000),
        }
      );
      const out = r.outBinds as {
        purchase_id: number;
        result_code: string;
        result_msg: string;
      };
      await patchLatestAuditLog(conn, clientIp, out.result_code);
      await conn.commit();
      return out;
    });

    return NextResponse.json({
      success: result.result_code === 'OK',
      code: result.result_code,
      message: result.result_msg,
      purchaseId: result.purchase_id,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Hata';
    return NextResponse.json({ success: false, message: msg }, { status: 500 });
  }
}
