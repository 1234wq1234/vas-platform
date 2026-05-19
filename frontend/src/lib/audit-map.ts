type AuditRow = Record<string, unknown>;

function deriveLogLevel(status: unknown): string {
  const s = String(status || '');
  if (s === 'SUCCESS') return 'INFO';
  if (s === 'FAILURE') return 'ERROR';
  return 'WARN';
}

function deriveResponseCode(status: unknown): string {
  const s = String(status || '');
  if (s === 'SUCCESS') return 'OK';
  if (s === 'FAILURE') return 'ERR';
  return s || '-';
}


export function enrichAuditRows(rows: AuditRow[]): AuditRow[] {
  return rows.map((row) => ({
    ...row,
    LOG_LEVEL: row.LOG_LEVEL ?? deriveLogLevel(row.STATUS_RESULT),
    RESPONSE_CODE: row.RESPONSE_CODE ?? deriveResponseCode(row.STATUS_RESULT),
  }));
}

export const AUDIT_SELECT_BASE = `
  SELECT log_id, action_code, action_category, subscriber_id, service_id,
         reference_id, performed_by, status_result, message, detail_json,
         ip_address, created_at
  FROM audit_logs
`;

export const AUDIT_SELECT_EXTENDED = `
  SELECT log_id, action_code, action_category, subscriber_id, service_id,
         reference_id, performed_by, status_result, message, detail_json,
         ip_address, log_level, response_code, created_at
  FROM audit_logs
`;
