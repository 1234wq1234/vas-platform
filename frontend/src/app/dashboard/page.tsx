'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { useToast } from '@/components/Toast';
import { formatApiMessage, fixTurkishText } from '@/lib/messages';

type Tab = 'islem' | 'rapor' | 'log';

interface User {
  username: string;
  displayName: string;
}

function todayStr() {
  return new Date().toISOString().slice(0, 10);
}

function weekAgoStr() {
  const d = new Date();
  d.setDate(d.getDate() - 7);
  return d.toISOString().slice(0, 10);
}

export default function DashboardPage() {
  const router = useRouter();
  const { showToast } = useToast();
  const [user, setUser] = useState<User | null>(null);
  const [tab, setTab] = useState<Tab>('islem');

  const [subscribers, setSubscribers] = useState<Record<string, unknown>[]>([]);
  const [services, setServices] = useState<Record<string, unknown>[]>([]);
  const [subscriptions, setSubscriptions] = useState<Record<string, unknown>[]>([]);
  const [auditLogs, setAuditLogs] = useState<Record<string, unknown>[]>([]);

  const [subId, setSubId] = useState('');
  const [svcId, setSvcId] = useState('');
  const [subIdCancel, setSubIdCancel] = useState('');
  const [topupSub, setTopupSub] = useState('');
  const [topupAmt, setTopupAmt] = useState('50');

  const [revenue24, setRevenue24] = useState(0);
  const [revenueWeek, setRevenueWeek] = useState(0);
  const [revenueMonth, setRevenueMonth] = useState(0);
  const [activeSubCount, setActiveSubCount] = useState(0);
  const [bestSelling, setBestSelling] = useState<Record<string, unknown>[]>([]);
  const [perfStart, setPerfStart] = useState('');
  const [perfEnd, setPerfEnd] = useState('');
  const [perfData, setPerfData] = useState<Record<string, unknown>[]>([]);

  const [logStart, setLogStart] = useState(todayStr());
  const [logEnd, setLogEnd] = useState(todayStr());
  const [logLoading, setLogLoading] = useState(false);

  const performedBy = user?.username || 'web';

  const notify = (success: boolean, code?: string, message?: string) => {
    showToast(success ? 'success' : 'error', formatApiMessage(success, code, message));
  };

  const loadBase = useCallback(async () => {
    const [subRes, svcRes, subListRes] = await Promise.all([
      fetch('/api/subscribers'),
      fetch('/api/services'),
      fetch('/api/subscriptions'),
    ]);
    const sub = await subRes.json();
    const svc = await svcRes.json();
    const subs = await subListRes.json();
    if (sub.success) setSubscribers(sub.data);
    if (svc.success) setServices(svc.data);
    if (subs.success) setSubscriptions(subs.data);
  }, []);

  const loadReports = useCallback(async () => {
    const [r24, rWeek, rMonth, active, best] = await Promise.all([
      fetch('/api/reports?type=revenue&period=24H'),
      fetch('/api/reports?type=revenue&period=WEEK'),
      fetch('/api/reports?type=revenue&period=MONTH'),
      fetch('/api/reports?type=active-subscriptions'),
      fetch('/api/reports?type=best-selling'),
    ]);
    const d24 = await r24.json();
    const dWeek = await rWeek.json();
    const dMonth = await rMonth.json();
    const dActive = await active.json();
    const dBest = await best.json();
    if (d24.success) setRevenue24(Number(d24.total) || 0);
    else showToast('error', d24.message || '24 saatlik ciro alinamadi.');
    if (dWeek.success) setRevenueWeek(Number(dWeek.total) || 0);
    if (dMonth.success) setRevenueMonth(Number(dMonth.total) || 0);
    if (dActive.success) setActiveSubCount(Number(dActive.total) || 0);
    if (dBest.success) setBestSelling(Array.isArray(dBest.data) ? dBest.data : []);
    else showToast('error', dBest.message || 'Satis raporu alinamadi.');
  }, [showToast]);

  const loadAudit = useCallback(
    async (start?: string, end?: string, mode: 'today' | 'range' = 'range') => {
      setLogLoading(true);
      const s = start ?? logStart;
      const e = end ?? logEnd;
      const params = new URLSearchParams({ limit: '300' });

      if (mode === 'today') {
        params.set('today', '1');
      } else if (s && e) {
        params.set('start', s);
        params.set('end', e);
      }

      try {
        const res = await fetch(`/api/audit?${params}`);
        const data = await res.json();
        if (data.success) {
          setAuditLogs(data.data);
          if (data.data.length === 0 && mode === 'range') {
            showToast('info', 'Seçilen tarih aralığında kayıt bulunamadı.');
          }
        } else {
          showToast('error', data.message || 'Günlükler yüklenemedi.');
        }
      } finally {
        setLogLoading(false);
      }
    },
    [logStart, logEnd, showToast]
  );

  useEffect(() => {
    const stored = sessionStorage.getItem('vas_user');
    if (!stored) {
      router.replace('/login');
      return;
    }
    setUser(JSON.parse(stored));
    loadBase();
    loadReports();
  }, [router, loadBase, loadReports]);

  useEffect(() => {
    if (tab === 'log') {
      const t = todayStr();
      setLogStart(t);
      setLogEnd(t);
      loadAudit(t, t, 'today');
    }
    if (tab === 'rapor') loadReports();
  }, [tab, loadAudit, loadReports]);

  async function handleSubscribe() {
    if (!subId || !svcId) {
      showToast('error', 'Lütfen abone ve servis seçin.');
      return;
    }
    const res = await fetch('/api/subscribe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subscriberId: subId, serviceId: svcId, performedBy }),
    });
    const data = await res.json();
    notify(data.success, data.code, data.message);
    loadBase();
    loadReports();
  }

  async function handlePurchase() {
    if (!subId || !svcId) {
      showToast('error', 'Lütfen abone ve servis seçin.');
      return;
    }
    const res = await fetch('/api/purchase', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subscriberId: subId, serviceId: svcId, performedBy }),
    });
    const data = await res.json();
    notify(data.success, data.code, data.message);
    loadBase();
    loadReports();
  }

  async function handleCancel() {
    if (!subIdCancel) {
      showToast('error', 'Lütfen iptal edilecek aboneliği seçin.');
      return;
    }
    const res = await fetch('/api/cancel', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subscriptionId: subIdCancel, performedBy }),
    });
    const data = await res.json();
    notify(data.success, data.code, data.message);
    loadBase();
    loadReports();
  }

  async function handleTopup() {
    if (!topupSub || !topupAmt) {
      showToast('error', 'Lütfen abone ve tutar girin.');
      return;
    }
    const res = await fetch('/api/topup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ subscriberId: topupSub, amount: topupAmt, performedBy }),
    });
    const data = await res.json();
    notify(data.success, data.success ? 'OK' : undefined, data.message);
    loadBase();
    loadReports();
  }

  async function loadPerformance() {
    if (!perfStart || !perfEnd) {
      showToast('error', 'Lütfen başlangıç ve bitiş tarihlerini seçin.');
      return;
    }
    const res = await fetch(
      `/api/reports?type=sales-performance&start=${perfStart}&end=${perfEnd}`
    );
    const data = await res.json();
    if (data.success) {
      setPerfData(data.data);
      showToast('info', 'Satış performansı hesaplandı.');
    } else {
      showToast('error', data.message || 'Rapor alınamadı.');
    }
  }

  function logout() {
    sessionStorage.removeItem('vas_user');
    router.push('/login');
  }

  const subServices = services.filter((s) => s.SERVICE_TYPE === 'SUBSCRIPTION' && s.STATUS === 'ACTIVE');
  const otServices = services.filter((s) => s.SERVICE_TYPE === 'ONE_TIME' && s.STATUS === 'ACTIVE');
  const activeSubs = subscriptions.filter((s) => s.STATUS === 'ACTIVE');

  const statusLabel: Record<string, string> = {
    SUCCESS: 'Başarılı',
    FAILURE: 'Başarısız',
    INFO: 'Bilgi',
  };

  const logLevelLabel: Record<string, string> = {
    INFO: 'Bilgi',
    ERROR: 'Hata',
    WARN: 'Uyarı',
  };

  return (
    <>
      <nav className="nav">
        <h1>VAS Platform</h1>
        <div className="nav-links">
          <span style={{ color: '#6b7280', fontSize: '0.9rem' }}>
            {user?.displayName || user?.username}
          </span>
          <button type="button" className="btn btn-secondary btn-logout" onClick={logout}>
            Çıkış
            <span className="btn-logout-arrow" aria-hidden="true">
              →
            </span>
          </button>
        </div>
      </nav>

      <div className="container">
        <div className="stat-grid">
          <div className="stat">
            <div className="value">{activeSubCount}</div>
            <div className="label">Aktif Abonelik</div>
          </div>
          <div className="stat">
            <div className="value">{Number(revenue24).toFixed(2)} TL</div>
            <div className="label">Son 24 Saat Ciro</div>
          </div>
          <div className="stat">
            <div className="value">{Number(revenueWeek).toFixed(2)} TL</div>
            <div className="label">Haftalık Ciro</div>
          </div>
          <div className="stat">
            <div className="value">{Number(revenueMonth).toFixed(2)} TL</div>
            <div className="label">Aylık Ciro</div>
          </div>
        </div>

        <div className="tabs">
          {(['islem', 'rapor', 'log'] as Tab[]).map((t) => (
            <button
              key={t}
              type="button"
              className={`tab ${tab === t ? 'active' : ''}`}
              onClick={() => setTab(t)}
            >
              {t === 'islem' ? 'İşlemler' : t === 'rapor' ? 'Raporlar' : 'İşlem Günlüğü'}
            </button>
          ))}
        </div>

        {tab === 'islem' && (
          <>
            <div className="card">
              <h2>Abonelik Aktif Et</h2>
              <p style={{ fontSize: '0.85rem', color: '#6b7280', marginBottom: '1rem' }}>
                Aynı servis tekrar aktif edilemez. İptal edilmeden yeniden alınamaz.
              </p>
              <div className="form-row">
                <div>
                  <label>Abone</label>
                  <select value={subId} onChange={(e) => setSubId(e.target.value)}>
                    <option value="">Seçin...</option>
                    {subscribers.map((s) => (
                      <option key={String(s.SUBSCRIBER_ID)} value={String(s.SUBSCRIBER_ID)}>
                        {String(s.FULL_NAME)} ({String(s.MSISDN)}) — {Number(s.BALANCE).toFixed(2)} TL
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label>Abonelik Servisi</label>
                  <select value={svcId} onChange={(e) => setSvcId(e.target.value)}>
                    <option value="">Seçin...</option>
                    {subServices.map((s) => (
                      <option key={String(s.SERVICE_ID)} value={String(s.SERVICE_ID)}>
                        {String(s.SERVICE_NAME)} — {Number(s.PRICE).toFixed(2)} TL
                      </option>
                    ))}
                  </select>
                </div>
              </div>
              <button type="button" className="btn" onClick={handleSubscribe}>
                Aboneliği Aktif Et
              </button>
            </div>

            <div className="card">
              <h2>Tek Seferlik Satın Al</h2>
              <p style={{ fontSize: '0.85rem', color: '#6b7280', marginBottom: '1rem' }}>
                Tekrar tekrar satın alınabilir. İptal edilemez.
              </p>
              <div className="form-row">
                <div>
                  <label>Abone</label>
                  <select value={subId} onChange={(e) => setSubId(e.target.value)}>
                    <option value="">Seçin...</option>
                    {subscribers.map((s) => (
                      <option key={String(s.SUBSCRIBER_ID)} value={String(s.SUBSCRIBER_ID)}>
                        {String(s.FULL_NAME)} — {Number(s.BALANCE).toFixed(2)} TL
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label>Tek Seferlik Servis</label>
                  <select value={svcId} onChange={(e) => setSvcId(e.target.value)}>
                    <option value="">Seçin...</option>
                    {otServices.map((s) => (
                      <option key={String(s.SERVICE_ID)} value={String(s.SERVICE_ID)}>
                        {String(s.SERVICE_NAME)} — {Number(s.PRICE).toFixed(2)} TL
                      </option>
                    ))}
                  </select>
                </div>
              </div>
              <button type="button" className="btn" onClick={handlePurchase}>
                Satın Al
              </button>
            </div>

            <div className="card">
              <h2>Abonelik İptal</h2>
              <label>Aktif Abonelik</label>
              <select value={subIdCancel} onChange={(e) => setSubIdCancel(e.target.value)}>
                <option value="">Seçin...</option>
                {activeSubs.map((s) => (
                  <option key={String(s.SUBSCRIPTION_ID)} value={String(s.SUBSCRIPTION_ID)}>
                    #{String(s.SUBSCRIPTION_ID)} — {String(s.FULL_NAME)} / {String(s.SERVICE_NAME)}
                  </option>
                ))}
              </select>
              <button type="button" className="btn btn-danger" onClick={handleCancel}>
                İptal Et
              </button>
            </div>

            <div className="card">
              <h2>Bakiye Yükle</h2>
              <div className="form-row">
                <div>
                  <label>Abone</label>
                  <select value={topupSub} onChange={(e) => setTopupSub(e.target.value)}>
                    <option value="">Seçin...</option>
                    {subscribers.map((s) => (
                      <option key={String(s.SUBSCRIBER_ID)} value={String(s.SUBSCRIBER_ID)}>
                        {String(s.FULL_NAME)}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label>Tutar (TL)</label>
                  <input value={topupAmt} onChange={(e) => setTopupAmt(e.target.value)} type="number" min="1" />
                </div>
              </div>
              <button type="button" className="btn" onClick={handleTopup}>
                Yükle
              </button>
            </div>
          </>
        )}

        {tab === 'rapor' && (
          <>
            <div className="card">
              <h2>En Çok Satılan Servisler</h2>
              <table>
                <thead>
                  <tr>
                    <th>Kod</th>
                    <th>Ad</th>
                    <th>Tip</th>
                    <th>Satış Adedi</th>
                    <th>Ciro</th>
                  </tr>
                </thead>
                <tbody>
                  {bestSelling.length === 0 && (
                    <tr>
                      <td colSpan={5} style={{ textAlign: 'center', color: '#6b7280' }}>
                        Henuz satis kaydi yok veya rapor paketi guncel degil.
                      </td>
                    </tr>
                  )}
                  {bestSelling.map((r, i) => (
                    <tr key={i}>
                      <td>{String(r.SERVICE_CODE)}</td>
                      <td>{String(r.SERVICE_NAME)}</td>
                      <td>
                        <span className={`badge ${r.SERVICE_TYPE === 'SUBSCRIPTION' ? 'badge-sub' : 'badge-ot'}`}>
                          {r.SERVICE_TYPE === 'SUBSCRIPTION' ? 'Abonelik' : 'Tek Seferlik'}
                        </span>
                      </td>
                      <td>{String(r.TOTAL_SALES)}</td>
                      <td>{Number(r.TOTAL_REVENUE).toFixed(2)} TL</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="card">
              <h2>Mesai Günü Satış Performansı</h2>
              <p style={{ fontSize: '0.85rem', color: '#6b7280', marginBottom: '1rem' }}>
                Seçilen tarih aralığında cumartesi ve pazar hariç mesai günleri
              </p>
              <div className="form-row">
                <div>
                  <label>Başlangıç</label>
                  <input type="date" value={perfStart} onChange={(e) => setPerfStart(e.target.value)} />
                </div>
                <div>
                  <label>Bitiş</label>
                  <input type="date" value={perfEnd} onChange={(e) => setPerfEnd(e.target.value)} />
                </div>
              </div>
              <button type="button" className="btn" onClick={loadPerformance}>
                Hesapla
              </button>
              {perfData.length > 0 && (
                <table style={{ marginTop: '1rem' }}>
                  <thead>
                    <tr>
                      <th>Tarih</th>
                      <th>İşlem Sayısı</th>
                      <th>Günlük Ciro</th>
                    </tr>
                  </thead>
                  <tbody>
                    {perfData.map((r, i) => (
                      <tr key={i}>
                        <td>{String(r.SALE_DATE).slice(0, 10)}</td>
                        <td>{String(r.TRANSACTION_COUNT)}</td>
                        <td>{Number(r.DAILY_REVENUE).toFixed(2)} TL</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </>
        )}

        {tab === 'log' && (
          <div className="card">
            <h2>İşlem Günlüğü</h2>
            <p style={{ fontSize: '0.85rem', color: '#6b7280', marginBottom: '1rem' }}>
              Bugünkü işlemler sayfa açıldığında otomatik listelenir. İsterseniz tarih aralığı seçerek filtreleyebilirsiniz.
            </p>
            <div className="audit-filter-row">
              <div>
                <label>Başlangıç Tarihi</label>
                <input type="date" value={logStart} onChange={(e) => setLogStart(e.target.value)} />
              </div>
              <div>
                <label>Bitiş Tarihi</label>
                <input type="date" value={logEnd} onChange={(e) => setLogEnd(e.target.value)} />
              </div>
              <div>
                <label className="audit-filter-spacer">&nbsp;</label>
                <button
                  type="button"
                  className="btn audit-filter-btn"
                  disabled={logLoading}
                  onClick={() => loadAudit(logStart, logEnd, 'range')}
                >
                  {logLoading ? 'Yükleniyor...' : 'Filtrele'}
                </button>
              </div>
              <div>
                <label className="audit-filter-spacer">&nbsp;</label>
                <button
                  type="button"
                  className="btn btn-secondary audit-filter-btn"
                  disabled={logLoading}
                  onClick={() => {
                    const s = weekAgoStr();
                    const e = todayStr();
                    setLogStart(s);
                    setLogEnd(e);
                    loadAudit(s, e, 'range');
                  }}
                >
                  Son 7 Gün
                </button>
              </div>
            </div>
            <table>
              <thead>
                <tr>
                  <th>Zaman</th>
                  <th>İşlem</th>
                  <th>Log Seviyesi</th>
                  <th>Response Code</th>
                  <th>IP Adresi</th>
                  <th>Durum</th>
                  <th>Mesaj</th>
                </tr>
              </thead>
              <tbody>
                {auditLogs.length === 0 && !logLoading && (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', color: '#6b7280' }}>
                      Kayıt bulunamadı.
                    </td>
                  </tr>
                )}
                {auditLogs.map((l, i) => (
                  <tr key={i}>
                    <td style={{ whiteSpace: 'nowrap' }}>{String(l.CREATED_AT).slice(0, 19)}</td>
                    <td>{String(l.ACTION_CODE)}</td>
                    <td>
                      <span className="badge badge-sub">
                        {logLevelLabel[String(l.LOG_LEVEL)] || String(l.LOG_LEVEL || '-')}
                      </span>
                    </td>
                    <td>{String(l.RESPONSE_CODE || '-')}</td>
                    <td>{String(l.IP_ADDRESS || '-')}</td>
                    <td>
                      <span
                        className={`badge ${
                          l.STATUS_RESULT === 'SUCCESS'
                            ? 'badge-active'
                            : l.STATUS_RESULT === 'FAILURE'
                              ? 'badge-cancelled'
                              : 'badge-ot'
                        }`}
                      >
                        {statusLabel[String(l.STATUS_RESULT)] || String(l.STATUS_RESULT)}
                      </span>
                    </td>
                    <td>{fixTurkishText(String(l.MESSAGE || ''))}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}
