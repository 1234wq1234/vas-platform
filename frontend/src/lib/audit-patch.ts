import type { OracleConnection } from '@/lib/oracle';

export async function patchLatestAuditLog(
  conn: OracleConnection,
  ip: string,
  responseCode?: string
) {
  try {
    await conn.execute(
      `UPDATE audit_logs
       SET ip_address = :ip,
           response_code = NVL(:code, response_code)
       WHERE log_id = (SELECT MAX(log_id) FROM audit_logs)`,
      { ip, code: responseCode || null }
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : '';
    if (!msg.includes('ORA-00904')) throw e;

    await conn.execute(
      `UPDATE audit_logs
       SET ip_address = :ip
       WHERE log_id = (SELECT MAX(log_id) FROM audit_logs)`,
      { ip }
    );
  }
}
