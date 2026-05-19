'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { formatConnectionError } from '@/lib/messages';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });
      const data = await res.json();
      if (!data.success) {
        setError(data.message || 'Giriş başarısız. Bilgilerinizi kontrol edin.');
        return;
      }
      sessionStorage.setItem('vas_user', JSON.stringify(data.user));
      router.push('/dashboard');
    } catch {
      setError('Sunucuya ulaşılamadı. Oracle bağlantı ayarlarınızı kontrol edin.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-page">
      <div className="login-box">
        <h1>VAS Platform</h1>
        <p>GSM Katma Değerli Servis Yönetimi</p>
        {error && <div className="alert alert-error">{formatConnectionError(error)}</div>}
        <form onSubmit={handleSubmit}>
          <label>Kullanıcı Adı</label>
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            required
          />
          <label>Şifre</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
          <button
            type="submit"
            className="btn btn-login"
            disabled={loading}
          >
            {loading ? 'Giriş yapılıyor...' : 'Giriş Yap'}
          </button>
        </form>
      </div>
    </div>
  );
}
