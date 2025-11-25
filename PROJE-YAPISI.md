# SplitWire-Turkey macOS - Proje Yapısı

## 📁 Dizin Yapısı

```
SplitWire-Turkey-macOS/
├── Package.swift                 # Swift Package Manager yapılandırması
├── build.sh                      # Uygulama derleme scripti
├── README.md                     # Genel proje dokümantasyonu
├── KULLANIM.md                   # Detaylı kullanım kılavuzu
├── PROJE-YAPISI.md              # Bu dosya
├── .gitignore                    # Git ignore kuralları
│
├── Sources/
│   └── SplitWireTurkey/
│       ├── SplitWireTurkeyApp.swift    # Ana uygulama giriş noktası
│       │
│       ├── Models/
│       │   └── AppState.swift           # Uygulama durumu yönetimi
│       │
│       ├── Views/
│       │   ├── ContentView.swift        # Ana görünüm
│       │   ├── WireGuardView.swift      # WireGuard kurulum arayüzü
│       │   ├── NetworkConfigView.swift  # Ağ ayarları arayüzü
│       │   └── AboutView.swift          # Hakkında ekranı
│       │
│       ├── Services/
│       │   ├── WireGuardService.swift   # WireGuard/wgcf yönetimi
│       │   └── NetworkConfigService.swift # DNS ve ağ yapılandırması
│       │
│       └── Resources/               # Kaynaklar klasörü (boş)
│
└── SplitWire-Turkey.app/            # Derlenmiş uygulama paketi
    └── Contents/
        ├── Info.plist               # Uygulama metadata
        ├── PkgInfo                  # Paket bilgisi
        └── MacOS/
            └── SplitWire-Turkey     # Çalıştırılabilir dosya
```

---

## 🏗️ Mimari Yapı

### SwiftUI + MVVM Pattern

Uygulama modern SwiftUI framework'ü kullanır ve MVVM (Model-View-ViewModel) mimarisini takip eder:

```
┌─────────────────┐
│     Views       │  ← Kullanıcı Arayüzü (SwiftUI)
│  - ContentView  │
│  - WireGuard    │
│  - NetworkConfig│
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│   AppState      │  ← ViewModel (ObservableObject)
│  - State Mgmt   │
│  - Settings     │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│    Services     │  ← İş Mantığı
│  - WireGuard    │
│  - Network      │
└─────────────────┘
```

---

## 📦 Modüller

### 1. **SplitWireTurkeyApp.swift**

Ana uygulama giriş noktası.

**Özellikler:**
- Uygulama başlatma
- AppDelegate yönetimi
- Yönetici yetki kontrolü
- Pencere yapılandırması

**Önemli Fonksiyonlar:**
```swift
@main
struct SplitWireTurkeyApp: App
class AppDelegate: NSObject, NSApplicationDelegate
```

### 2. **AppState.swift**

Uygulama genelinde paylaşılan durum yönetimi.

**Özellikler:**
- Kullanıcı ayarları (tema, dil)
- WireGuard durumu
- Özel klasör listesi
- Tarayıcı tünelleme tercihi

**Published Properties:**
```swift
@Published var isDarkMode: Bool
@Published var selectedLanguage: Language
@Published var isWireGuardConfigured: Bool
@Published var customFolders: [String]
@Published var includeBrowsers: Bool
```

### 3. **WireGuardService.swift**

WireGuard ve wgcf yönetimi.

**Özellikler:**
- wgcf indirme ve kurulum
- WireGuard profil oluşturma
- Tünel yönetimi (başlat/durdur)
- Özel uygulama listesi yapılandırması

**Ana Metodlar:**
```swift
func installStandard(includeBrowsers: Bool)
func installCustom(customFolders: [String], includeBrowsers: Bool)
func uninstall()
private func registerAndGenerateProfile()
private func installTunnel()
```

### 4. **NetworkConfigService.swift**

DNS ve ağ yapılandırması.

**Özellikler:**
- DNS sunucu yönetimi
- Ağ arayüzü bilgileri
- DNS önbellek temizleme
- AppleScript ile yönetici işlemleri

**Ana Metodlar:**
```swift
func setOptimalDNS()
func resetDNS()
func flushDNSCache()
func getCurrentDNS()
func getPrimaryInterface()
```

---

## 🎨 Görünümler (Views)

### ContentView

Ana konteyner görünümü.

**Bileşenler:**
- HeaderView: Logo, dil seçici, tema toggle
- TabView: Sekme yönetimi
- StatusBarView: Durum mesajları

### WireGuardView

WireGuard kurulum ve yönetim arayüzü.

**Özellikler:**
- Durum göstergesi
- Standart kurulum butonu
- Özel klasör ekleme
- Tarayıcı tünelleme toggle
- Kaldırma işlemleri

### NetworkConfigView

DNS ve ağ ayarları arayüzü.

**Özellikler:**
- Mevcut DNS görüntüleme
- Optimal DNS ayarlama
- DNS sıfırlama
- Önbellek temizleme
- Ağ arayüzü bilgileri

### AboutView

Hakkında ve krediler ekranı.

**Bileşenler:**
- Uygulama bilgileri
- Özellikler listesi
- Teşekkürler
- Lisans bilgisi
- Bağlantılar

---

## 🔧 Teknik Detaylar

### Kullanılan Teknolojiler

| Teknoloji | Versiyon | Kullanım |
|-----------|----------|----------|
| Swift | 5.9+ | Ana programlama dili |
| SwiftUI | - | Kullanıcı arayüzü |
| AppKit | - | macOS entegrasyonu |
| Combine | - | Reactive programming |
| WireGuard | - | VPN tünelleme |
| wgcf | 2.2.20 | Cloudflare WARP config |

### Sistem Gereksinimleri

- **Minimum:** macOS 13.0 (Ventura)
- **Önerilen:** macOS 14.0 (Sonoma) veya üzeri
- **Mimari:** x86_64 (Intel) / ARM64 (Apple Silicon)

### Yetki Gereksinimleri

Bazı işlemler yönetici yetkisi gerektirir:

1. **WireGuard Kurulumu**
   - `/etc/wireguard/` dizinine yazma
   - Ağ tüneli oluşturma
   - LaunchDaemon kurulumu

2. **DNS Ayarları**
   - `networksetup` komutları
   - Sistem ağ ayarlarını değiştirme

3. **DNS Önbellek**
   - `dscacheutil -flushcache`
   - `mDNSResponder` yeniden başlatma

---

## 🔄 Veri Akışı

### WireGuard Kurulum Akışı

```
Kullanıcı "Kurulum Yap" Butonuna Tıklar
        ↓
WireGuardView butonu devre dışı bırakır
        ↓
WireGuardService.installStandard() çağrılır
        ↓
1. wgcf indirilir (yoksa)
        ↓
2. wgcf register --accept-tos
        ↓
3. wgcf generate (profil oluştur)
        ↓
4. Profil yapılandırılır (AllowedApps eklenir)
        ↓
5. /etc/wireguard/wgcf.conf'a kopyalanır
        ↓
6. sudo wg-quick up wgcf
        ↓
7. LaunchDaemon kurulur (otomatik başlatma)
        ↓
AppState.checkWireGuardStatus() güncellenir
        ↓
Kullanıcıya başarı mesajı gösterilir
```

### DNS Yapılandırma Akışı

```
Kullanıcı "Optimal DNS Ayarla" Tıklar
        ↓
NetworkConfigService.setOptimalDNS() çağrılır
        ↓
1. Birincil ağ arayüzü bulunur (getPrimaryInterface)
        ↓
2. AppleScript ile yönetici yetkisi istenir
        ↓
3. networksetup -setdnsservers <interface> 8.8.8.8 9.9.9.9
        ↓
4. DNS ayarları tekrar okunur (getCurrentDNS)
        ↓
UI güncellenir, başarı mesajı gösterilir
```

---

## 🐛 Hata Ayıklama

### Debug Build

```bash
swift build
.build/debug/SplitWire-Turkey
```

### Console Logları

```bash
# Uygulama loglarını izle
log stream --predicate 'process == "SplitWire-Turkey"' --level debug

# WireGuard logları
sudo wg show
cat /var/log/system.log | grep wireguard
```

### Xcode Debug

```bash
# Xcode projesi oluştur
swift package generate-xcodeproj
open SplitWire-Turkey-macOS.xcodeproj
```

---

## 🚀 Geliştirme

### Yeni Özellik Ekleme

1. **Model güncelle** (`AppState.swift`)
2. **Service oluştur/güncelle** (`Services/`)
3. **View oluştur** (`Views/`)
4. **ContentView'e entegre et**

### Örnek: Yeni Sekme Ekleme

```swift
// 1. AppState.swift'e state ekle
@Published var newFeatureEnabled = false

// 2. Yeni Service oluştur
class NewFeatureService: ObservableObject {
    @Published var status = ""

    func performAction() async { ... }
}

// 3. Yeni View oluştur
struct NewFeatureView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var service = NewFeatureService()

    var body: some View { ... }
}

// 4. ContentView'e ekle
TabView {
    // ... mevcut sekmeler

    NewFeatureView()
        .tabItem {
            Label("Yeni Özellik", systemImage: "star")
        }
        .tag(3)
}
```

---

## 📝 Lisans

MIT License - Detaylar için [LICENSE](LICENSE) dosyasına bakın.

---

## 🔗 İlgili Dosyalar

- [README.md](README.md) - Genel bilgiler ve kurulum
- [KULLANIM.md](KULLANIM.md) - Detaylı kullanım kılavuzu
- [build.sh](build.sh) - Derleme scripti

---

**Son Güncelleme:** 2025-10-22
**Versiyon:** 1.5.4 macOS Edition
