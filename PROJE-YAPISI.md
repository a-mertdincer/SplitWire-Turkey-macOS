# SplitWire-Turkey macOS - Proje Yapısı

Sürüm: 1.1.1 · SwiftPM (tools 5.9, Swift 5 dil modu) · SwiftUI + AppKit · macOS 13+ · evrensel (arm64 + x86_64)

## Dizin yapısı

```
SplitWire-Turkey-macOS/
├── Package.swift                  # SwiftPM: SplitWire-Turkey (executable) + SplitWireTurkeyTests
├── build.sh                       # Sürüm derlemesi: ön kontroller, evrensel .app + ciadpi, ad-hoc imza, doğrulama, zip
├── scripts/
│   ├── build-ciadpi.sh            # byedpi/ kaynaklarından ciadpi derler (evrensel veya --arch-native)
│   └── verify-app.sh              # .app veya .zip doğrulama (imza, mimari, minos, Info.plist, CFBundleLocalizations, sha256)
├── byedpi/                        # ByeDPI v17.3 kaynakları (hufrea, MIT) — ciadpi buradan derlenir
├── AppIcon.icns / AppIcon.iconset # Uygulama simgesi
├── splitwire-logo-128.png         # README logosu
├── README.md                      # Türkçe + İngilizce genel bakış
├── KULLANIM.md                    # Türkçe kullanım kılavuzu
├── PROJE-YAPISI.md                # Bu dosya
├── RELEASE_NOTES_v1.1.1.md        # Sürüm notları (v1.1.1, #13)
├── RELEASE_NOTES_v1.1.0.md        # Sürüm notları (v1.1.0)
├── LICENSE                        # MIT
│
├── Sources/SplitWireTurkey/
│   ├── SplitWireTurkeyApp.swift   # @main, tek Window sahnesi, AppDelegate (çıkış akışı, sistem menü dili), AppInfo
│   ├── Models/
│   │   └── AppState.swift         # Arayüz durumu: dil, koyu mod, Dock simgesi, favori uygulamalar
│   ├── Services/
│   │   ├── ByeDPIService.swift          # ciadpi süreç yönetimi (tek örnek), preset, durum izleme, çıkış hazırlığı
│   │   ├── SystemProxyService.swift     # networksetup ile sistem SOCKS + HTTPS proxy aç/kapat/tara
│   │   ├── AppLauncher.swift            # Favori uygulamayı argümanlarla başlatma (NSWorkspace)
│   │   ├── MenuBarService.swift         # NSStatusItem menüsü; ByeDPIService'i izler
│   │   ├── MainWindowController.swift   # Ana pencereyi geri getirme + DockIconController
│   │   ├── NetworkConfigService.swift   # DNS okuma/ayarlama (servis adı ile), önbellek temizleme
│   │   ├── DNSHealthChecker.swift       # Discord/Roblox DNS zehirlenmesi kontrolü (sistem DNS vs DoH, engelleme adresi)
│   │   ├── DoHProfile.swift             # Cloudflare DoH .mobileconfig üretimi
│   │   ├── WireGuardService.swift       # wgcf indirme/doğrulama, WARP profili, uç nokta sabitleme, wg-quick, isteğe bağlı LaunchDaemon
│   │   └── Shell.swift                  # Süreç çalıştırma, kaçış yardımcıları, yönetici komutları
│   ├── Support/                         # Saf mantık (UI/yan etki yok, birim testli)
│   │   ├── ByeDPIPresets.swift          # Preset tablosu, kayıt taşıma, argüman ayrıştırma/oluşturma
│   │   ├── Localization.swift           # AppLanguage, L10n, L("tr", "en"), LocalizedText / LT("tr", "en")
│   │   ├── NetworkSetupParser.swift     # route / networksetup / lsof çıktısı ayrıştırıcıları
│   │   └── LineRingBuffer.swift         # ciadpi stderr'inin son satırları
│   └── Views/
│       ├── ContentView.swift            # Başlık (dil, Dock, koyu mod) + sekmeler
│       ├── ByeDPIView.swift             # ByeDPI sekmesi, Hızlı İşlemler, Sistem Proxy sayfası, Roblox notu
│       ├── NetworkConfigView.swift      # Ağ Ayarları sekmesi
│       ├── DNSHealthBanner.swift        # DNS uyarı kutusu + DoH profili sayfası
│       ├── WireGuardView.swift          # WireGuard sekmesi
│       └── AboutView.swift              # Hakkında sekmesi
│
└── Tests/SplitWireTurkeyTests/
    ├── ByeDPIPresetsTests.swift             # Preset sırası/argümanları, Fake yok, taşıma, argüman oluşturma (-G), editAsCustom
    ├── ByeDPIServiceIntegrationTests.swift  # Gerçek ciadpi: başlat/yeniden başlat/durdur, yalnızca 127.0.0.1, SOCKS5 + HTTP CONNECT, boş Custom
    ├── DNSTests.swift                       # DNS zehirlenmesi kararı (Discord/Roblox), uyarı metni, DoH JSON, scutil ayrıştırma, DoH profili
    ├── LocalizationTests.swift              # Dil seçimi, eski anahtar taşıma, bildirim, LocalizedText, AppleLanguages eşitleme
    ├── NetworkSetupParserTests.swift        # networksetup/lsof ayrıştırma, SOCKS/HTTPS proxy durumu ve komutları, Shell, LineRingBuffer
    ├── WireGuardTests.swift                 # wgcf indirme adayları, Mach-O/SHA-256, uç nokta sabitleme, komut üretimi, plist
    └── TestLanguage.swift                   # Testlerde dili geçici ayarlama yardımcısı
```

Derleme çıktıları (git'e girmez): `.build/`, `build/` (ara ciadpi ve sahneleme), `SplitWire-Turkey.app`, `dist/` (zip + .sha256), `byedpi/ciadpi` (geliştirme ikilisi).

---

## Mimari

```
┌───────────────────────────────┐      ┌───────────────────────────┐
│ Views (SwiftUI)               │      │ MenuBarService (AppKit)   │
│ ContentView, ByeDPIView, ...  │      │ NSStatusItem menüsü       │
└──────────────┬────────────────┘      └─────────────┬─────────────┘
               │ @EnvironmentObject / @ObservedObject │ Combine (objectWillChange)
               ▼                                      ▼
┌──────────────────────────────────────────────────────────────────┐
│ Paylaşılan örnekler (uygulama düzeyinde, @MainActor)             │
│ AppState.shared · ByeDPIService.shared                           │
│ SystemProxyService.shared · NetworkConfigService.shared          │
│ DNSHealthChecker.shared · WireGuardService.shared                │
└──────────────┬───────────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────┐   ┌──────────────────────────────┐
│ Shell                        │   │ Support (saf mantık)         │
│ run: kabuksuz, ana thread    │   │ ByeDPIPresets, Localization, │
│ dışında, zaman aşımlı        │   │ NetworkSetupParser, ...      │
│ runPrivileged: osascript     │   └──────────────────────────────┘
│ "with prompt … with          │
│ administrator privileges"    │
└──────────────────────────────┘
```

Temel kurallar:

- **Tek doğruluk kaynağı:** Pencere ve menü çubuğu aynı `ByeDPIService.shared` örneğini kullanır. Menü çubuğunun kendi süreç/preset durumu yoktur (v1.0.0'daki "pencere Standart, menü Disorder" sorunu, #12).
- **Görünümler durum tutmaz:** Dil değişince pencere ağacı `.id(selectedLanguage)` ile yeniden kurulur; süren işlemler servislerde olduğu için kaybolmaz.
- **Ana iş parçacığı bloklanmaz:** Tüm alt süreçler `Shell.run` ile arka plan kuyruğunda çalışır; stdout/stderr eşzamanlı okunur, zaman aşımı vardır.
- **Kabuk enjeksiyonu yok:** Kullanıcı girdisi veya yol içeren komutlar argüman dizisi ile (kabuksuz) çalıştırılır. Yönetici olarak çalışan kabuk komutlarında değişken parçalar `Shell.shellQuote`, AppleScript literali `Shell.appleScriptStringLiteral` ile kaçırılır.
- **Yönetici yetkisi yalnızca gerektiğinde:** Uygulama root olarak çalışmaz. DNS değişikliği/önbellek temizleme, sistem proxy aç/kapat, WireGuard kur/bağlan/kes/kaldır ve gerekirse "Tümünü Zorla Kapat" için standart macOS parola penceresi gösterilir; her çağıran nedenini yerelleştirilmiş `prompt` metniyle yazar. Birden çok adım tek pencerede birleştirilir. `do shell script` root olarak `PATH=/usr/bin:/bin:/usr/sbin:/sbin` ile çalıştığından komutlarda mutlak yollar kullanılır.
- **Mantık metne bakmaz:** Kararlar kalıcı kimliklere (preset id, `AppLanguage`) ve durum türlerine dayanır, yerelleştirilmiş metinlere değil.
- **Gereksiz yayın yok:** Servisler `@Published` değerleri yalnızca değiştiklerinde atar; menü çubuğu menü açıkken yeniden kurulmaz (kapanınca kurulur).

---

## Modüller

### SplitWireTurkeyApp.swift

- `SplitWireTurkeyApp`: Tek `Window` sahnesi (id `main`), "Hakkında" (derleme numarası + commit) ve Pencere menüsünde "Ana Pencereyi Göster" (⌘0) komutları.
- `AppDelegate`:
  - Dock simgesi tercihini pencere görünmeden uygular, menü çubuğunu kurar, ByeDPI izlemeyi başlatır.
  - `syncSystemUILanguage`: Uygulama içi dil macOS'un seçeceği dilden farklıysa yalnızca uygulamanın alanında `AppleLanguages` ayarlar (açılışta ve dil değişince); sistem menüleri bir sonraki açılışta seçilen dile geçer (#8).
  - Açılışta DNS kontrolü yapar ve "sistem proxy açık ama 1080'de kimse dinlemiyor" durumunu algılayıp kullanıcıya sorar (#14).
  - Son pencere kapanınca çıkmaz; Dock simgesine tıklanınca pencereyi geri getirir.
  - Her çıkış yolunda (`applicationShouldTerminate` → `.terminateLater`) `ByeDPIService.prepareForQuit()`: açık bir "proxy'yi aç" penceresini en çok 60 sn bekler, sistem proxy'yi kapatır (120 sn parola zaman aşımı) ve ancak proxy kapandıktan sonra ciadpi'yi durdurur. Sonuç `.proxyStillOn` ise kritik uyarı sorar: Tekrar Dene (`retryDisableProxyForQuit`) / ByeDPI çalışsın, çık / Çıkma (`resumeAfterCancelledQuit`). Oturum kapatma/yeniden başlatma/kapatmada (`kAEQuitReason`) sorulmaz.
- `AppInfo`: Sürüm (`CFBundleShortVersionString`, paketsiz çalıştırmada "dev"), derleme (`CFBundleVersion`), commit (`SWGitCommit`), telif, proje bağlantıları.

### Models/AppState.swift

`ObservableObject`; `isDarkMode`, `selectedLanguage`, `hideDockIcon`, `favoriteApps`, `selectedTab`. Açılışta v1.0.0'ın kullanılmayan `customFolders` / `includeBrowsers` anahtarlarını siler.

### Services/ByeDPIService.swift

- ciadpi'yi `Process` ile doğrudan başlatır; argümanlar `ByeDPIArguments.build` ile oluşturulur (`-i 127.0.0.1 -p 1080 -G` yoksa eklenir). `-G` (`--http-connect`) aynı porta HTTP CONNECT desteği ekler: ciadpi önce SOCKS sürüm baytına, sonra `CONNECT`'e bakar, yani SOCKS5 istemcileri etkilenmez. Sistem HTTPS proxy'si bunu kullanır (#13).
- `enableSystemProxy()`: Harici (bu oturumda başlatılmamış) bir ciadpi'nin komut satırında `-G`/`--http-connect` yoksa (ör. v1.1.0'dan kalma) sistem proxy açılmaz; HTTPS proxy CONNECT'i desteklemeyen bir sürece yönlenmesin diye kullanıcıdan yeniden başlatması istenir.
- Başlatmadan önce 1080'deki LISTEN soketlerini `lsof` ile kontrol eder: kalmış ciadpi ise kapatıp yeniden denemeyi önerir, başka program ise adını ve PID'sini gösterir.
- Harici ciadpi tüm arayüzlerde dinliyorsa (v1.0.0, `-i` yok) `isExposedToNetwork` yayınlanır (pencere + menü çubuğunda uyarı); kendi kullanıcımızın süreci için PID başına bir kez "127.0.0.1'de güvenli yeniden başlat" önerilir. Böyle bir süreç `start()` için "çalışıyor" sayılmaz.
- Başlattıktan 0,6 sn sonra süreç kapanmışsa stderr'in son satırlarıyla hata gösterir.
- Durdurma: ciadpi macOS'ta SIGTERM/SIGINT ile kapanmadığı için kısa bekleme sonrası SIGKILL.
- 2,5 sn'de bir durum yoklaması (her 4 turda bir sistem proxy taraması). Bu oturumda başlatılmamış ciadpi "harici" olarak gösterilir ve durdurulabilir.
- Preset seçimi kaydedilir; çalışıyorsa ve argümanlar değiştiyse yeniden başlatır. Custom boşsa çalışan süreç öldürülmez. `restart()`: yeni yöntem başlamazsa önceki argümanlarla bir kez yeniden açar; o da olmazsa sistem proxy'yi kapatır.
- `editAsCustom()`: Custom argümanları yalnızca boşsa veya bir hazır presetle aynıysa seçili yöntemle doldurur; kullanıcının kaydettiği argümanları ezmez.
- Durdurma ve "Tümünü Zorla Kapat" bizim sistem proxy'mizi kapatır (iptal edilirse durum mesajında uyarı); beklenmedik durmada kullanıcıya sorar. Çıkış: `prepareForQuit()` → `QuitPreparation` (`.clean` / `.proxyStillOn`).
- Varsayılan olmayan portta (testler) kendi `SystemProxyService(port:)` örneğini kullanır; gerçek 127.0.0.1:1080 proxy'sine dokunmaz.
- `launchFavoriteApp`: Gerekirse ByeDPI'ı başlatır, ardından `AppLauncher` ile uygulamayı açar.
- `findCiadpiPath`: `Contents/Resources/bin/ciadpi` → geliştirmede `<repo>/byedpi/ciadpi`.

### Services/SystemProxyService.swift

"Bizim proxy" = herhangi bir ağ servisinde SOCKS **veya** güvenli web proxy'si (HTTPS) açık ve `127.0.0.1:1080`'i gösteriyor (`OurProxyState.detect`, saf ve testli; v1.1.0'ın yalnızca-SOCKS ayarı da algılanır). `refresh()` tüm servislerde `-getsocksfirewallproxy` ve `-getsecurewebproxy` okur (ikisinin çıktı biçimi aynıdır, `NetworkSetupParser.parseProxySettings`) ve `activeProxies`'i yayınlar; açılıştaki eski proxy kontrolü, durdurma/çökme/çıkışta otomatik kapatma, pencere ve menü çubuğu bunu kullanır. `enable()` birincil servisi `NetworkConfigService.resolvePrimaryService()` ile bulur (VPN/utun ise fiziksel servise düşer; yoksa `noActiveService`). Serviste başka bir sunucuyu gösteren açık SOCKS/HTTPS proxy varsa (`OurProxyState.foreignProxy`, saf ve testli) üzerine yazmaz, `foreignProxy` hatası verir. Aksi halde tek yetkili komutla (`enableCommand(services:)`) birincil serviste ve bizi gösteren yarım ayarı olan diğer servislerde SOCKS ve HTTPS proxy'yi ayarlayıp açar. Yetkili komut aynı root kabukta önce `lsof … -c ciadpi` ile dinleyiciyi doğrular, yoksa `SPLITWIRE_NO_LISTENER` ile çıkar (`noListener`). `disableAll()` bizim proxy'nin açık olduğu tüm servislerde yalnızca bizi gösteren türleri (SOCKS ve/veya HTTPS) tek parola penceresinde kapatır; başka sunucuya ayarlı kullanıcı proxy'sine dokunmaz. Düz web proxy'si (HTTP) asla ayarlanmaz (ciadpi `GET http://…` biçimli istekleri karşılayamaz) ve bypass listesi değiştirilmez. `hasIncompleteSetup`: bir serviste türlerden yalnızca biri açık ve aynı serviste kullanıcının kendi proxy'si (`hasForeignProxy`) açık değil (sayfada "Aç" yeniden etkinleşir; tek basışta tamamlanır). `isBusy` sürerken pencere ve menü çubuğunda Başlat/Durdur/preset devre dışıdır. `init(host:port:)` testler için enjekte edilebilir.

### Services/AppLauncher.swift

Uygulamayı `NSWorkspace.openApplication` ile argümanlarla açar (kabuk yok). Argümanlar yalnızca yeni başlatılan örneğe iletildiğinden uygulama açıksa "Kapat ve Yeniden Başlat" önerir; 8 sn'de kapanmazsa zorla kapatmayı sorar.

### Services/MenuBarService.swift

`NSStatusItem` (kalkan simgesi). `ByeDPIService`, `SystemProxyService` ve `AppState` değişikliklerini Combine ile izleyip menüyü yeniden kurar (menü açıkken kapanana kadar erteler; simge hemen güncellenir); tüm işlemleri `ByeDPIService`'e devreder. Dil değişince başlıkları yeniden üretir.

### Services/MainWindowController.swift

- `MainWindowController.show()`: Pencere kapatılmış ve Dock simgesi gizli olsa bile ana pencereyi açar/öne getirir (sahnenin `openWindow` eylemi, yedek olarak ⌘0 menü komutu).
- `DockIconController`: `NSApp.setActivationPolicy(.accessory / .regular)` (#6).

### Services/NetworkConfigService.swift

- Varsayılan rotanın arayüzünü (`en0`) `networksetup -listnetworkserviceorder` ile **servis adına** (`Wi-Fi`) çevirir. v1.0.0 `networksetup`'a `en0` veriyordu ve DNS hiç değişmiyordu (#11). Varsayılan rota bir VPN tüneliyse IPv4 adresi olan ilk fiziksel servise düşer.
- `DNSPreset`: Cloudflare (önerilen), Google, Quad9. DHCP'ye sıfırlama, önbellek temizleme (`dscacheutil -flushcache; killall -HUP mDNSResponder`).
- `setDNSCommand`: `networksetup -setdnsservers … && { <önbellek temizleme>; }`; networksetup'ın çıkış kodu ve hata metni kullanıcıya ulaşır.
- `scutil --dns` ile DHCP'de gerçekte kullanılan sunucuları gösterir.

### Services/DNSHealthChecker.swift

`DNSHealthChecker.targets` (`DNSCheckTarget`: ad, servis, kural) adlarını sistem çözümleyicisi (`getaddrinfo`, ciadpi'nin kullandığıyla aynı; yalnızca IPv4) ile çözer:

- `discord.com`, `gateway.discord.gg` (Discord, `compareWithDoH`): ayrıca DoH (1.1.1.1, 8.8.8.8, ... JSON API; proxy'siz, önbelleksiz oturum) ile çözülür.
- `www.roblox.com` (Roblox, `knownBlockIPOnly`, #13): yalnızca engelleme adreslerine bakılır: `knownBlockIPs`, `isNonRoutable` (0.0.0.0/8, 127.0.0.0/8) ve aynı kontrolde Discord hedeflerinin zehirli bulunduğu sistem adresleri (`evaluateAll` iki geçişte değerlendirir). Roblox CDN adresleri çözümleyiciye göre değiştiği için başka bir adres zehirli sayılmaz, DoH sorgusu yapılmaz.

`DNSHealthEvaluator`:

- Bilinen engelleme adresi (`195.175.254.2` ve IPv6 karşılığı) → zehirli (DoH'a ulaşılamasa bile).
- DoH sonucu yoksa veya sistem adres döndürmediyse → bilinmiyor (yanlış alarm yok).
- `compareWithDoH`: Sistem adreslerinin hiçbiri DoH adresleriyle aynı /16 ağında değilse → zehirli.
- `combine`: biri zehirliyse zehirli (adresler birleştirilir), hepsi doğruysa doğru, aksi halde bilinmiyor. `affectedServices` / `affectedHosts` uyarı metnine ("Discord ve Roblox için…", `LList`) girer.

### Services/DoHProfile.swift

`com.apple.dnsSettings.managed` yükü içeren `.mobileconfig` üretir (Cloudflare DoH, `ServerAddresses` ile; böylece `cloudflare-dns.com` adı zehirli DNS ile çözülmez). `~/Downloads/SplitWire-Cloudflare-DoH.mobileconfig` olarak kaydedip açar; yüklemeyi kullanıcı Sistem Ayarları'nda yapar.

### Services/WireGuardService.swift

- `WireGuardSupport` (saf, testli): sabitler, işlemci tespiti (`hw.optional.arm64`; Rosetta altında da doğru), `downloadCandidates` (önce SHA-256'sı gömülü sabit v2.3.0; daha yeni sürüm yalnızca GitHub özet veriyorsa yedek; özetsiz dosya yok), Mach-O ve mimari doğrulama, profil/`ifconfig` ayrıştırma (paylaşılan WARP adresi 172.16.0.2 daha özgül adres varsa yok sayılır), `parseEndpoint`/`pinEndpoint`, LaunchDaemon plist'i ve yönetici komutlarının üretimi.
- `wg-quick` Homebrew'da (`/opt/homebrew/bin` veya `/usr/local/bin`) aranır; aynı klasörde `bash`, `wg`, `wireguard-go` olmalıdır. Komutlar ve LaunchDaemon bu klasörü PATH'e ekler (Homebrew wg-quick bash 4+ ister).
- Kurulumda uç nokta ana makine adı DoH ile çözülüp ilk IPv4 adresine sabitlenir (çözülemezse ad kalır; IP olmayan değer yapılandırmaya yazılmaz).
- Kurulum tek parola penceresi: `/etc/wireguard/wgcf.conf` (root:wheel 600), eski tünel `down` → eski wg-quick izleyicisinin bitmesini bekleme (en çok 10 sn) → `wg-quick up`. LaunchDaemon (`/Library/LaunchDaemons/com.splitwire.wireguard.plist`, RunAtLoad, `launchctl bootstrap`) yalnızca "Açılışta otomatik bağlan" (`wireGuardStartAtBoot`, varsayılan kapalı) seçiliyse kurulur; seçili değilse var olan daemon boşaltılıp silinir. Seçenek, Homebrew'un kullanıcı tarafından yazılabilir wg-quick/bash/wg/wireguard-go'sunu açılışta root olarak çalıştırdığı için arayüzde güvenlik uyarısıyla gösterilir.
- Bağlantı durumu: profildeki adreslerden birini taşıyan `utun` arayüzü aranır.
- Tünel tüm trafiği taşır (`AllowedIPs = 0.0.0.0/0, ::/0`); macOS'ta uygulama bazlı tünel yoktur.

### Services/Shell.swift

- `Shell.run(executable, args, environment:, timeout:)`: Kabuksuz, arka planda; çıplak komut adları `/usr/bin`, `/opt/homebrew/bin`, `/usr/local/bin` vb. içinde aranır.
- `Shell.bash(script)`: Yalnızca sabit (kullanıcı girdisi içermeyen) kabuk komutları için.
- `Shell.runPrivileged(command, prompt:, timeout:)`: `osascript -e 'do shell script ... with prompt ... with administrator privileges'` (betik `privilegedScript` ile üretilir, testli); iptal (-128) `ShellError.userCancelled` olarak ayrılır.

### Support/

- `ByeDPIPresets.swift`: Sıralı preset tablosu (Fake yok), `migrate` (eski `menuBarPreset` → `byedpiPreset`, bilinmeyen/kaldırılmış → Standart), `ByeDPIArguments` (tırnak destekli `tokenize`, `build` (`-i`/`-p`/`-G` ekler), `containsHTTPConnect`, `commandLineSupportsHTTPConnect`, `displayString`).
- `Localization.swift`: `AppLanguage` (tr/en), `L10n.current` (iş parçacığı güvenli, `appLanguage` anahtarı, eski `language` anahtarını taşır), `L(_:_:)`; servis durum mesajları için iki dili saklayan ve okunurken çözülen `LocalizedText` / `LT(_:_:)`.
- `NetworkSetupParser.swift`: `route -n get default`, `networksetup -listnetworkserviceorder / -listallnetworkservices / -getsocksfirewallproxy / -getsecurewebproxy` (`ProxySettings`), `lsof -F pcun` ayrıştırıcıları (`PortListener`: PID başına dinleme adresleri, `isLoopbackOnly`).
- `LineRingBuffer.swift`: Son N satırı tutan kilitli halka tampon.

---

## Yerelleştirme

Tüm arayüz metinleri tek çağrıda iki dille yazılır:

```swift
Text(L("ByeDPI'ı Başlat", "Start ByeDPI"))
Text(LocalizedStringKey(L("**Not:** ...", "**Note:** ...")))   // Markdown içeren metin
```

Servislerin durum mesajları `LT("…", "…")` ile iki dilde saklanır (`statusMessage` okunurken çözülür), böylece dil değişince eski mesajlar da çevrilir.

Teknik metinler (CLI argümanları, komutlar, yollar, IP'ler) çevrilmez. Dil değişince `.appLanguageDidChange` yayınlanır; pencere yeniden kurulur, menü çubuğu yenilenir ve `AppDelegate.syncSystemUILanguage` çalışır. AppKit'in kendi menüleri için Info.plist'te `CFBundleLocalizations` = `[en, tr]` vardır; bunlar bir sonraki açılışta seçilen dile geçer.

---

## Kalıcı ayarlar (UserDefaults)

Alan adı: `com.cagritaskin.splitwire-turkey` (v1.0.0 sürümüyle aynı; ayarlar güncellemede korunur).

| Anahtar | Açıklama |
|---|---|
| `byedpiPreset` | Seçili DPI yöntemi (preset id) |
| `menuBarPreset` | v1.0.0 menü çubuğu seçimi (yalnızca taşıma için okunur) |
| `byedpiCustomArgs` | Özel (Custom) parametreler |
| `appLanguage` | `tr` / `en` (eski `language` anahtarından taşınır) |
| `hideDockIcon` | Dock simgesi gizli mi |
| `isDarkMode` | Koyu mod |
| `favoriteApps` | Hızlı İşlemler uygulamaları (JSON) |
| `wireGuardStartAtBoot` | WireGuard "Açılışta otomatik bağlan" (varsayılan kapalı) |
| `AppleLanguages` | Yalnızca uygulama içi dil sistem diliyle uyuşmazsa ayarlanır (sistem menülerinin dili) |

---

## Veri akışları

### ByeDPI başlatma

```
Başlat (pencere / menü çubuğu / favori uygulama)
  → ByeDPIService.start()
  → argümanlar: -i 127.0.0.1 -p 1080 -G + preset (veya Custom)
  → lsof: 1080 boş mu? (kalmış ciadpi → kapat ve tekrar dene önerisi)
  → Process.run(ciadpi) → 0,6 sn sonra hâlâ çalışıyor mu?
  → isRunning / runningPreset / runningArgs yayınlanır → pencere + menü çubuğu güncellenir
```

### Durdurma / çıkış

```
Durdur → SIGTERM, ardından SIGKILL → 1080'de kalan kendi ciadpi'lerimizi öldür
       → bizim sistem proxy açıksa (SOCKS ve/veya HTTPS): networksetup ...state off (tek parola penceresi; iptal → uyarı)
Çıkış  → applicationShouldTerminate (.terminateLater) → prepareForQuit
       → proxy kapandı: ciadpi öldür → çık
       → proxy kapanmadı: Tekrar Dene / ByeDPI çalışsın, çık / Çıkma (oturum sonunda sormadan çık)
```

### DNS ayarlama

```
"DNS'i Cloudflare Yap" → birincil servis adı (Wi-Fi)
  → runPrivileged: networksetup -setdnsservers 'Wi-Fi' 1.1.1.1 1.0.0.1 && { dscacheutil -flushcache; killall -HUP mDNSResponder || true; }
  → networksetup -getdnsservers ile doğrula → 2 sn sonra DNSHealthChecker yeniden kontrol
```

### WireGuard kurulumu

```
wg-quick + bash/wg/wireguard-go var mı? (yoksa: brew install wireguard-tools)
  → wgcf: Homebrew / ~/.local/bin / GitHub (önce sabit v2.3.0; doğru mimari, Mach-O + SHA-256 doğrulama)
  → wgcf register --accept-tos (hesap yoksa) → wgcf generate
  → Endpoint DoH ile çözülüp IPv4'e sabitlenir → ~/.config/wireguard/wgcf.conf
  → (yalnızca açılışta otomatik bağlan seçiliyse) LaunchDaemon plist'i geçici klasöre yazılır
  → runPrivileged (tek pencere): /etc/wireguard/wgcf.conf, [plist | eski plist'i sil], wg-quick down → bekle → up, [launchctl bootstrap]
  → utun arayüzü görünene kadar durum yenilenir
```

---

## Derleme ve test

```bash
./build.sh                    # evrensel sürüm + dist/SplitWire-Turkey-v<VERSION>.zip (+ .sha256)
./build.sh --arch-native      # yalnızca bu Mac'in mimarisi, zip yok
./build.sh --help             # tüm seçenekler (VERSION, --skip-zip, --clean, BUILD_NUMBER, SCRATCH_PATH, ALLOW_DIRTY, SDKROOT)

scripts/build-ciadpi.sh --arch-native   # byedpi/ciadpi (swift run / swift test için)
swift run
swift test
scripts/verify-app.sh SplitWire-Turkey.app [--archs "arm64 x86_64"]
```

`build.sh` adımları:

0. Ön kontroller: Command Line Tools + `@State`'in makro olduğu SDK (ör. macOS 27) birlikteyse durur (CLT'de `libSwiftUIMacros` yok; tam Xcode veya `SDKROOT=$(xcrun --sdk macosx26.5 --show-sdk-path)`). Derleme girdilerinde (`Package.swift Sources byedpi scripts build.sh AppIcon.icns`, izlenmeyen dosyalar dahil) commit'lenmemiş değişiklik varsa zip oluşturmayı reddeder (`--skip-zip` veya `ALLOW_DIRTY=1` hariç); HEAD `v<VERSION>` etiketli değilse uyarır.
1. `swift build -c release --arch arm64 --arch x86_64` (yürütülebilir dosyanın her iki mimariyi içerdiği doğrulanır).
2. `scripts/build-ciadpi.sh`: `byedpi/Makefile`'daki kaynaklar (Windows dosyaları hariç) `-mmacosx-version-min=13.0` ile tek `cc` çağrısında derlenir; `ciadpi --version` ile (Apple Silicon'da x86_64 dilimi Rosetta ile) doğrulanır.
3. Paket: `Contents/MacOS/SplitWire-Turkey`, `Contents/Resources/bin/ciadpi`, `AppIcon.icns`, `Info.plist` (`LSMinimumSystemVersion` 13.0, bundle id `com.cagritaskin.splitwire-turkey`, `CFBundleLocalizations` `[en, tr]`, `SWGitCommit` = kısa commit, değişiklik varsa `-dirty` ekli).
4. İçten dışa ad-hoc imza: önce ciadpi, sonra paket (hardened runtime yok).
5. `scripts/verify-app.sh`: `codesign --verify --deep --strict`, kaynakların mühürlü olması, mimariler, `minos` ≤ 13.0, `CFBundleLocalizations`'ta `tr`, ciadpi'nin çalışması.
6. `ditto -c -k --norsrc --keepParent` ile zip + `.sha256`; zip açılıp tekrar doğrulanır.

Testler sistem ayarlarına dokunmaz. Entegrasyon testleri gerçek ciadpi'yi `127.0.0.1:41873` üzerinde çalıştırır (sistem proxy servisi de bu porta bakar, gerçek 1080 ayarına dokunulmaz), her presetin yalnızca loopback'te dinlediğini ve aynı portun hem SOCKS5 hem HTTP CONNECT el sıkışmasını kabul ettiğini kontrol eder; ciadpi yoksa atlanır. Yukarıdaki Command Line Tools kısıtı `swift build` / `swift run` / `swift test` için de geçerlidir.

Xcode ile çalışmak için: `open Package.swift`.

---

## İlgili dosyalar

- [README.md](README.md): Genel bilgi, kurulum, sorun giderme (TR/EN)
- [KULLANIM.md](KULLANIM.md): Ayrıntılı kullanım kılavuzu
- [RELEASE_NOTES_v1.1.1.md](RELEASE_NOTES_v1.1.1.md): v1.1.1 değişiklikleri (#13: Roblox, SOCKS + HTTPS sistem proxy)
- [RELEASE_NOTES_v1.1.0.md](RELEASE_NOTES_v1.1.0.md): v1.1.0 değişiklikleri
- [LICENSE](LICENSE): MIT
