# SplitWire-Turkey macOS - Kullanım Kılavuzu

## 📦 Kurulum

### Adım 1: Uygulamayı Derleyin

```bash
cd /Users/mert/Downloads/SplitWire-Turkey-macOS
./build.sh
```

### Adım 2: Applications Klasörüne Taşıyın

```bash
cp -r SplitWire-Turkey.app /Applications/
```

### Adım 3: Uygulamayı Açın

```bash
open /Applications/SplitWire-Turkey.app
```

**İlk Açılışta:** "Tanımlanamayan geliştirici" uyarısı alabilirsiniz. Çözüm:
1. Sistem Ayarları > Gizlilik ve Güvenlik > "Yine de Aç" butonuna tıklayın
2. Veya Terminal'den: `xattr -d com.apple.quarantine /Applications/SplitWire-Turkey.app`

---

## 🚀 İlk Kullanım

### WireGuard Kurulumu

1. **SplitWire-Turkey**'i açın
2. **WireGuard** sekmesine gidin
3. (Opsiyonel) "Tarayıcılar için de tünelleme yap" seçeneğini işaretleyin
4. **"Standart Kurulum Yap"** butonuna tıklayın
5. Yönetici şifrenizi girin
6. Kurulum tamamlandığında bilgisayarınızı yeniden başlatın

### DNS Optimizasyonu

1. **Ağ Ayarları** sekmesine gidin
2. **"Optimal DNS Ayarla"** butonuna tıklayın
3. Bu işlem Google (8.8.8.8) ve Quad9 (9.9.9.9) DNS sunucularını ayarlar

---

## 🔧 Gelişmiş Özellikler

### Özel Klasör Ekleme

Discord dışında başka uygulamalar için tünelleme yapmak isterseniz:

1. **WireGuard** sekmesinde **"Klasör Ekle"** butonuna tıklayın
2. Uygulamanın `.app` dosyasını seçin (örn: `/Applications/Spotify.app`)
3. **"Özel Kurulum"** butonuna tıklayın

### DNS Önbelleğini Temizleme

Bağlantı sorunları yaşıyorsanız:

1. **Ağ Ayarları** sekmesine gidin
2. **"DNS Önbelleğini Temizle"** butonuna tıklayın

---

## 🐛 Sorun Giderme

### WireGuard Başlamıyor

Terminal'de kontrol edin:

```bash
# WireGuard durumunu görüntüle
sudo wg show

# Manuel başlatma
sudo wg-quick up wgcf

# Manuel durdurma
sudo wg-quick down wgcf
```

### wgcf İndirilemedi

Manuel kurulum:

```bash
mkdir -p ~/.local/bin
curl -Lo ~/.local/bin/wgcf https://github.com/ViRb3/wgcf/releases/latest/download/wgcf_2.2.20_darwin_amd64
chmod +x ~/.local/bin/wgcf
```

### DNS Değişiklikleri Uygulanmıyor

```bash
# DNS önbelleğini manuel temizleme
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Ağ ayarlarını sıfırlama
sudo networksetup -setdnsservers Wi-Fi empty
```

### Yapılandırma Dosyası Bulunamadı

WireGuard yapılandırma dosyalarının konumu:

```bash
# Yapılandırma klasörü
~/.config/wireguard/

# Dosyalar
~/.config/wireguard/wgcf.conf
~/.config/wireguard/wgcf-account.toml
~/.config/wireguard/wgcf-profile.conf
```

Manuel temizlik:

```bash
rm -rf ~/.config/wireguard/wgcf*
```

---

## 📝 Terminal Komutları

### WireGuard İşlemleri

```bash
# Tünel durumunu kontrol et
sudo wg show

# Tüneli başlat
sudo wg-quick up wgcf

# Tüneli durdur
sudo wg-quick down wgcf

# Yapılandırmayı görüntüle
cat ~/.config/wireguard/wgcf.conf
```

### Ağ Bilgileri

```bash
# Birincil ağ arayüzünü bul
route -n get default | grep interface

# Mevcut DNS sunucularını görüntüle
scutil --dns

# DNS'i DHCP'ye sıfırla
sudo networksetup -setdnsservers Wi-Fi empty

# Belirli DNS sunucuları ayarla
sudo networksetup -setdnsservers Wi-Fi 8.8.8.8 9.9.9.9
```

### Sistem Logları

```bash
# Sistem loglarını görüntüle
log show --predicate 'process == "wireguard"' --last 10m

# WireGuard logları
cat /var/log/system.log | grep wireguard
```

---

## ⚠️ Önemli Notlar

### Yönetici Yetkileri

Bu uygulama bazı işlemler için yönetici (sudo) yetkileri gerektirir:
- WireGuard tüneli kurulumu
- DNS ayarlarını değiştirme
- Sistem servisleri yönetimi

### Güvenlik

- Tüm yapılandırma dosyaları yerel sistemde saklanır
- Hiçbir veri dışarıya gönderilmez
- WireGuard bağlantısı şifrelidir

### Performans

- WireGuard minimal CPU ve bellek kullanır
- Bağlantı hızınızı etkilemez
- Sadece seçili uygulamalar tünellenir (split tunneling)

---

## 🔄 Güncelleme

Yeni bir versiyon çıktığında:

```bash
# Eski uygulamayı kaldır
rm -rf /Applications/SplitWire-Turkey.app

# Yeni versiyonu derle
cd /Users/mert/Downloads/SplitWire-Turkey-macOS
git pull
./build.sh

# Yeni versiyonu yükle
cp -r SplitWire-Turkey.app /Applications/
```

---

## 🗑️ Tamamen Kaldırma

Uygulamayı ve tüm yapılandırmayı kaldırmak için:

```bash
# WireGuard'ı durdur
sudo wg-quick down wgcf

# LaunchDaemon'u kaldır
sudo launchctl unload /Library/LaunchDaemons/com.splitwire.wireguard.plist
sudo rm /Library/LaunchDaemons/com.splitwire.wireguard.plist

# Yapılandırma dosyalarını sil
rm -rf ~/.config/wireguard/wgcf*
sudo rm -f /etc/wireguard/wgcf.conf

# wgcf'yi sil
rm ~/.local/bin/wgcf

# Uygulamayı sil
rm -rf /Applications/SplitWire-Turkey.app

# DNS'i sıfırla
sudo networksetup -setdnsservers Wi-Fi empty
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

---

## 📞 Destek

Sorun yaşıyorsanız:

1. Bu kılavuzu kontrol edin
2. [README.md](README.md) dosyasını okuyun
3. [GitHub Issues](https://github.com/cagritaskn/SplitWire-Turkey/issues) sayfasında arama yapın
4. Yeni bir issue açın (varsa log dosyalarını ekleyin)

---

## 💡 İpuçları

### En İyi Performans

1. Sadece gerekli uygulamaları tünele ekleyin
2. DNS ayarlarını optimize edin
3. WireGuard tünelini gereksiz yere durdurup başlatmayın

### Güvenli Kullanım

1. Sadece güvenilir kaynaklardan wgcf indirin
2. WireGuard yapılandırmanızı kimseyle paylaşmayın
3. Düzenli olarak güncellemeleri kontrol edin

### Hız Testi

```bash
# Tünelsiz hız testi
curl -o /dev/null http://speedtest.tele2.net/100MB.zip

# Tünelli hız testi
sudo wg-quick up wgcf
curl -o /dev/null http://speedtest.tele2.net/100MB.zip
sudo wg-quick down wgcf
```

---

**Son Güncelleme:** 2025-10-22
