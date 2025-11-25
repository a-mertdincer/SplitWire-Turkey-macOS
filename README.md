# SplitWire Turkey - macOS

Modern macOS uygulaması ile ByeDPI ve WireGuard yönetimi.

## Özellikler

### ByeDPI Yönetimi
- ✅ 8 farklı DPI bypass yöntemi (Standart, Split 1/2, Disorder, Fake, OOB, vs.)
- ✅ Menu bar'dan hızlı erişim ve kontrol
- ✅ Otomatik yöntem değiştirme ve yeniden başlatma
- ✅ Sistem proxy ayarları entegrasyonu
- ✅ Favori uygulamalarınızı proxy ile başlatma
- ✅ Her uygulama için özel parametreler
- ✅ Ana pencere ve menu bar senkronize durum gösterimi
- ✅ Port bazlı process temizleme (Kill All)

### WireGuard Yönetimi
- WireGuard profil yönetimi
- Kolay yapılandırma arayüzü

## Kurulum

1. [Releases](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/releases) sayfasından son sürümü indirin
2. `SplitWire-Turkey.app` dosyasını Applications klasörüne sürükleyin
3. Uygulamayı açın

## Kullanım

### ByeDPI ile Sitelere Erişim

1. **ByeDPI'ı başlatın**: Ana pencereden veya menu bar'dan "Başlat" butonuna tıklayın
2. **DPI yöntemi seçin**: Bazı siteler farklı yöntemlerle çalışır
   - **Standart**: Genel kullanım için
   - **Disorder**: Genelde en etkili yöntem
   - **Split + Disorder**: Kombine güç
   - Diğer yöntemleri de deneyebilirsiniz
3. **Favori uygulamalarınızı ekleyin**: Chrome, Firefox, Discord, vs.
4. **Sistem proxy'yi aktif edin** (opsiyonel): Tüm sistem trafiği ByeDPI üzerinden geçer

### ERR_CONNECTION_RESET Hatası

Bir siteye giremiyorsanız:
1. Menu bar ikonuna tıklayın
2. "DPI Yöntemi" menüsünden farklı bir yöntem seçin
3. Otomatik olarak yeniden başlatılır
4. Siteyi tekrar deneyin

Önerilen deneme sırası:
1. Disorder
2. Split + Disorder
3. Split 2
4. Fake -1
5. OOB

## Derleme

```bash
# Gereksinimler
# - Swift 5.9+
# - macOS 13.0+

# Derleme
swift build -c release

# App bundle oluşturma
./scripts/build-app.sh  # (TODO: Script eklenecek)
```

## Katkıda Bulunma

Bu proje orijinal [SplitWire-Turkey-macOS](https://github.com/ORJINAL_REPO_URL) projesinin geliştirilmiş versiyonudur.

Katkılarınızı bekliyoruz! Pull request göndermekten çekinmeyin.

## Lisans

Bu proje orijinal projenin lisansını takip eder.

## Teşekkürler

- [ciadpi](https://github.com/nomoresat/DPI-bypass-multi) - DPI bypass aracı
- Orijinal SplitWire Turkey projesi ekibi

## Ekran Görüntüleri

(TODO: Ekran görüntüleri eklenecek)

## Sorun Giderme

**Uygulama açılmıyor:**
- Sistem Ayarları > Gizlilik ve Güvenlik bölümünden "Yine de Aç" seçeneğini kullanın

**ByeDPI başlamıyor:**
- Terminal'den şu komutu çalıştırın: `sudo lsof -ti:1080 | xargs kill -9`
- Ardından uygulamadan tekrar başlatın

**Process kapatamıyorum:**
- Menu bar'dan "Tümünü Zorla Kapat" seçeneğini kullanın
- Bu seçenek sudo yetkisi ister ve port 1080'i tamamen temizler

## İletişim

Sorularınız için [Issues](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues) bölümünü kullanabilirsiniz.
