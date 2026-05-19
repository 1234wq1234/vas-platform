import { NextRequest, NextResponse } from 'next/server';
import { withConnection, OraBind } from '@/lib/oracle';
import { formatConnectionError, fixTurkishText } from '@/lib/messages';
import { getClientIp } from '@/lib/client-ip';
import { patchLatestAuditLog } from '@/lib/audit-patch';

export async function POST(req: NextRequest) {
  try {
    const { username, password } = await req.json();
    if (!username || !password) {
      return NextResponse.json(
        { success: false, message: 'Kullanıcı adı ve şifre gereklidir.' },
        { status: 400 }
      );
    }

    const clientIp = getClientIp(req);

    const result = await withConnection(async (conn) => {
      const r = await conn.execute(
        `BEGIN
           pkg_vas_core.validate_login(
             :username, :password,
             :user_id, :display_name, :result_code, :result_msg
           );
         END;`,
        {
          username,
          password,
          user_id: OraBind.outNumber(),
          display_name: OraBind.outString(100),
          result_code: OraBind.outString(50),
          result_msg: OraBind.outString(1000),
        }
      );
      const out = r.outBinds as {
        user_id: number;
        display_name: string;
        result_code: string;
        result_msg: string;
      };
      await patchLatestAuditLog(conn, clientIp, out.result_code);
      await conn.commit();
      return out;
    });

    if (result.result_code !== 'OK') {
      return NextResponse.json(
        { success: false, message: 'Kullanıcı adı veya şifre hatalı.' },
        { status: 401 }
      );
    }

    return NextResponse.json({
      success: true,
      user: {
        id: result.user_id,
        username,
        displayName: fixTurkishText(result.display_name || username),
      },
    });
  } catch (e) {
    const raw = e instanceof Error ? e.message : 'Bağlantı hatası';
    return NextResponse.json(
      { success: false, message: formatConnectionError(raw) },
      { status: 500 }
    );
  }
}
