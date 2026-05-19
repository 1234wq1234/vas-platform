/** API sonuç kodları → kullanıcı dostu Türkçe mesajlar */
const CODE_MESSAGES: Record<string, string> = {
  OK: 'İşlem başarıyla tamamlandı.',
  SUBSCRIBER_NOT_FOUND: 'Abone bulunamadı. Lütfen geçerli bir abone seçin.',
  SUBSCRIBER_INACTIVE: 'Abone hesabı aktif değil. İşlem yapılamaz.',
  SERVICE_NOT_FOUND: 'Servis bulunamadı.',
  SERVICE_INACTIVE: 'Servis şu anda aktif değil.',
  WRONG_SERVICE_TYPE: 'Seçilen servis bu işlem türü için uygun değil.',
  INSUFFICIENT_BALANCE: 'Yetersiz bakiye. Lütfen önce bakiye yükleyin.',
  DUPLICATE_SUBSCRIPTION:
    'Bu abonenin seçilen servis için zaten aktif bir aboneliği var. İptal etmeden yeniden alınamaz.',
  SUBSCRIPTION_NOT_ACTIVE: 'Abonelik zaten iptal edilmiş veya aktif değil.',
  SUBSCRIPTION_NOT_FOUND: 'Abonelik kaydı bulunamadı.',
  INVALID_CREDENTIALS: 'Kullanıcı adı veya şifre hatalı.',
  SERVICE_CODE_EXISTS: 'Bu servis kodu zaten kullanılıyor.',
  SYSTEM_ERROR: 'Sistem hatası oluştu. Lütfen tekrar deneyin.',
};

/** Oracle/ASCII metinlerdeki eksik Türkçe karakterleri düzeltir */
export function fixTurkishText(text: string): string {
  return text
    .replace(/\bdegil\b/gi, 'değil')
    .replace(/\bDegil\b/g, 'Değil')
    .replace(/\bolmali\b/gi, 'olmalı')
    .replace(/\bBasarili\b/g, 'Başarılı')
    .replace(/\bbasarili\b/gi, 'başarılı')
    .replace(/\bBasarisiz\b/g, 'Başarısız')
    .replace(/\bbasarisiz\b/gi, 'başarısız')
    .replace(/\bGiris\b/g, 'Giriş')
    .replace(/\bgiris\b/gi, 'giriş')
    .replace(/\bYukleme\b/g, 'Yükleme')
    .replace(/\byuklendi\b/gi, 'yüklendi')
    .replace(/\bIptal\b/g, 'İptal')
    .replace(/\biptal\b/gi, 'iptal')
    .replace(/\bSecin\b/g, 'Seçin')
    .replace(/\bsecin\b/gi, 'seçin')
    .replace(/\bIslem\b/g, 'İşlem')
    .replace(/\bislem\b/gi, 'işlem')
    .replace(/\bCikis\b/g, 'Çıkış')
    .replace(/\bcikis\b/gi, 'çıkış')
    .replace(/\bYetersiz\b/g, 'Yetersiz')
    .replace(/\bone-time\b/gi, 'tek seferlik')
    .replace(/\bOne-time\b/g, 'Tek seferlik');
}

export function formatApiMessage(
  success: boolean,
  code?: string,
  rawMessage?: string
): string {
  if (success) {
    if (code && CODE_MESSAGES[code]) return CODE_MESSAGES[code];
    if (rawMessage) return fixTurkishText(rawMessage);
    return 'İşlem başarıyla tamamlandı.';
  }

  if (code && CODE_MESSAGES[code]) return CODE_MESSAGES[code];
  if (rawMessage) return fixTurkishText(rawMessage);
  return 'İşlem gerçekleştirilemedi. Lütfen bilgileri kontrol edip tekrar deneyin.';
}

export function formatConnectionError(message: string): string {
  if (message.includes('NJS-518') || message.includes('NJS-519') || message.includes('not registered with the listener')) {
    return (
      'Oracle veritabanı listener\'a kayıtlı değil. Listener ve XE servisinin çalıştığını kontrol edin, ' +
      'ardından frontend/.env bağlantı ayarlarını doğrulayıp npm run dev\'i yeniden başlatın.'
    );
  }
  if (message.includes('NJS-045') || message.includes('NJS-500')) {
    return 'Oracle istemcisi bulunamadı. Oracle Instant Client kurulu ve PATH değişkenine ekli olmalıdır.';
  }
  return fixTurkishText(message);
}
