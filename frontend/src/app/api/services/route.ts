import { NextRequest, NextResponse } from 'next/server';
import { withConnection, rowsToArray, OraBind } from '@/lib/oracle';

export async function GET() {
  try {
    const rows = await withConnection(async (conn) => {
      const r = await conn.execute(
        `SELECT service_id, service_code, service_name, service_type, price, status, description
         FROM services ORDER BY service_type, service_name`
      );
      return rowsToArray(r);
    });
    return NextResponse.json({ success: true, data: rows });
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Hata';
    return NextResponse.json({ success: false, message: msg }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { serviceCode, serviceName, serviceType, price, description, performedBy } = body;

    const result = await withConnection(async (conn) => {
      const r = await conn.execute(
        `BEGIN
           pkg_vas_core.add_service(
             :code, :name, :type, :price, :desc,
             :performed_by, :service_id, :result_code, :result_msg
           );
         END;`,
        {
          code: serviceCode,
          name: serviceName,
          type: serviceType,
          price: Number(price),
          desc: description || null,
          performed_by: performedBy || 'web',
          service_id: OraBind.outNumber(),
          result_code: OraBind.outString(50),
          result_msg: OraBind.outString(1000),
        }
      );
      await conn.commit();
      return r.outBinds as { service_id: number; result_code: string; result_msg: string };
    });

    return NextResponse.json({
      success: result.result_code === 'OK',
      code: result.result_code,
      message: result.result_msg,
      serviceId: result.service_id,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Hata';
    return NextResponse.json({ success: false, message: msg }, { status: 500 });
  }
}
