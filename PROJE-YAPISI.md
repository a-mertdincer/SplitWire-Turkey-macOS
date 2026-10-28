# SplitWire-Turkey macOS - Proje Yapısı

Sürüm: 1.1.3 · SwiftPM (tools 5.9, Swift 5 dil modu) · SwiftUI + AppKit · macOS 13+ · evrensel (arm64 + x86_64)

## Dizin yapısı

```
SplitWire-Turkey-macOS/
├── Package.swift                  # SwiftPM: SplitWire-Turkey (executable) + SplitWireTurkeyTests
├── build.sh                       # Sürüm derlemesi: ön kontroller, evrensel .app + ciadpi, ad-hoc imza, doğrulama, zip
├── scripts/
│   ├── build-ciadpi.sh            # byedpi/ kaynaklarından ciadpi derler (evrensel veya --arch-native)
│   └── verify-app.sh              # .app veya .zip doğrulama (imza, mimari, minos, Info.plist, CFBundleLocalizations, sha256)
├── byedpi/                        # ByeDPI v17.3 kaynakları (hufrea, MIT) + SplitWire yaması (proxy.c: CONNECT hedefi istek satırından) — ciadpi buradan derlenir
├── AppIcon.icns / AppIcon.iconset # Uygulama simgesi
├── splitwire-logo-128.png         # README logosu
├── README.md                      # Türkçe + İngilizce genel bakış
├── KULLANIM.md                    # Türkçe kullanım kılavuzu
├── PROJE-YAPISI.md                # Bu dosya
├── RELEASE_NOTES_v1.1.3.md        # Sürüm notları (v1.1.3, ciadpi HTTP CONNECT port düzeltmesi)
├── RELEASE_NOTES_v1.1.2.md        # Sürüm notları (v1.1.2, #15 ve #13)
├── RELEASE_NOTES_v1.1.1.md        # Sürüm notları (v1.1.1, #13)
├── RELEASE_NOTES_v1.1.0.md        # Sürüm notları (v1.1.0)
├── LICENSE                        # MIT
│
├── Sources/SplitWireTurkey/
│   ├── SplitWireTurkeyApp.swift   # @main, tek Window sahnesi, AppDelegate (çıkış akışı, sistem menü dili), AppInfo
│   ├── Models/
│   │   └── AppState.swift         # Arayüz durumu: dil, koyu mod, Dock simgesi, favori uygulamalar
│   ├── Services/
│   │   ├── ByeDPIService.swift          # ciadpi süreç yönetimi (tek örnek), preset, durum izleme, favori başlatma, çıkış hazırlığı
│   │   ├── SystemProxyService.swift     # networksetup ile sistem SOCKS + HTTPS proxy aç/kapat/tara
│   │   ├── AppLauncher.swift            # Favori uygulamayı argümanlar + ortam değişkenleriyle (HTTPS_PROXY) başlatma; açıksa uygulamayı yardımcılarıyla birlikte kapatma (NSWorkspace)
│   │   ├── SelfRestartWatcher.swift     # Hızlı İşlemler uygulamalarının proxy'siz kendini yeniden başlatmasını yakalar (NSWorkspace bildirimleri)
│   │   ├── ConnectionTester.swift       # ByeDPI üzerinden bağlantı testi (Discord, Discord güncelleyicisi TLS 1.2, Roblox) ve teşhis
│   │   ├── MenuBarService.swift         # NSStatusItem menüsü; ByeDPIService'i izler
│   │   ├── MainWindowController.swift   # Ana pencereyi geri getirme + DockIconController
│   │   ├── NetworkConfigService.swift   # DNS okuma/ayarlama (servis adı ile), önbellek temizleme
│   │   ├── DNSHealthChecker.swift       # Discord/Roblox DNS zehirlenmesi kontrolü (sistem DNS vs DoH, engelleme adresi)
│   │   ├── DoHProfile.swift             # Cloudflare DoH .mobileconfig üretimi
│   │   ├── WireGuardService.swift       # wgcf indirme/doğrulama, WARP profili, uç nokta sabitleme, wg-quick, isteğe bağlı LaunchDaemon
│   │   └── Shell.swift                  # Süreç çalıştırma, kaçış yardımcıları, yönetici komutları
│   ├── Support/                         # Saf mantık (UI/yan etki yok, birim testli)
│   │   ├── ByeDPIPresets.swift          # Preset tablosu (varsayılan Split 2), kayıt taşıma, argüman ayrıştırma/oluşturma, proxy ortamı
│   │   ├── SelfRestartPolicy.swift      # Kendi kendine yeniden başlatma kararı (SelfRestartPolicy, SelfRestartTracker)
│   │   ├── KnownApps.swift              # Özel davranışlı uygulamalar: Roblox ve menü çubuğu yardımcısı (birlikte kapatma, sormadan zorla kapatma)
│   │   ├── Localization.swift           # AppLanguage, L10n, L("tr", "en"), LocalizedText / LT("tr", "en")
│   │   ├── NetworkSetupParser.swift     # route / networksetup / lsof çıktısı ayrıştırıcıları
│   │   └── LineRingBuffer.swift         # ciadpi stderr'inin son satırları
│   └── Views/
│       ├── ContentView.swift            # Başlık (dil, Dock, koyu mod) + sekmeler
│       ├── ByeDPIView.swift             # ByeDPI sekmesi, bağlantı testi görünümü, Hızlı İşlemler, Sistem Proxy sayfası, Roblox notu
│       ├── NetworkConfigView.swift      # Ağ Ayarları sekmesi
│       ├── DNSHealthBanner.swift        # DNS uyarı kutusu + DoH profili sayfası
│       ├── WireGuardView.swift          # WireGuard sekmesi
│       └── AboutView.swift              # Hakkında sekmesi
│
└── Tests/SplitWireTurkeyTests/
    ├── AppLaunchTests.swift                 # Kendi kendine yeniden başlatma (SelfRestartTrackerTests; sınıra yalnızca gerçek yeniden açmalar sayılır), KnownApps, bağlantı testi teşhisi (ConnectionDiagnosisTests)
    ├── ByeDPIPresetsTests.swift             # Preset sırası/argümanları, varsayılan Split 2, Fake yok, taşıma (Standart → Split 2 bir kez), argüman oluşturma (-G), proxy ortamı, editAsCustom
    ├── ByeDPIServiceIntegrationTests.swift  # Gerçek ciadpi: başlat/yeniden başlat/durdur, yalnızca 127.0.0.1, SOCKS5 + HTTP CONNECT, CONNECT hedef portu istek satırından (portsuz Host), boş Custom
    ├── DNSTests.swift                       # DNS zehirlenmesi kararı (Discord/Roblox), uyarı metni, DoH JSON, scutil ayrıştırma, DoH profili
    ├── LocalizationTests.swift              # Dil seçimi, eski anahtar taşıma, bildirim, LocalizedText ("Split 2 (önerilen)"), AppleLanguages eşitleme
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
│ ConnectionTester.shared                                          │
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

- ciadpi'yi `Process` ile doğrudan başlatır; argümanlar `ByeDPIArguments.build` ile oluşturulur (`-i 127.0.0.1 -p 1080 -G` yoksa eklenir). `-G` (`--http-connect`) aynı porta HTTP CONNECT desteği ekler: ciadpi önce SOCKS sürüm baytına, sonra `CONNECT`'e bakar, yani SOCKS5 istemcileri etkilenmez. Sistem HTTPS proxy'si (#13), favorilere verilen `HTTPS_PROXY` ve bağlantı testi bunu kullanır (#15). Vendored ciadpi'de tek SplitWire yaması vardır (`byedpi/proxy.c`, `connect_target`): CONNECT hedefi `Host` başlığından değil istek satırından (`CONNECT host:port`) okunur. macOS'un ağ yığını (URLSession, WebKit; bağlantı testi, Roblox'un giriş doğrulaması, Sistem Proxy kullanan Safari) `Host`'a port yazmaz; yamasız ciadpi o zaman 80'e bağlanıyordu (v1.1.3).
- Açılışta preset: `ByeDPIPresets.migrate` (eski anahtar, bilinmeyen/kaldırılmış → Split 2), ardından `migrateOldDefault` (v1.1.2 tek seferlik geçiş: kayıtlı Standart → Split 2; `byedpiPresetMigratedToSplit2` ile bir kez). Geçiş yapıldıysa `.info` durum mesajı gösterilir; kullanıcı Standart'ı yeniden seçerse korunur. `defaultCustomArgs` = `-s 2 --tlsrec 1+s`.
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
- `launchFavoriteApp`: Gerekirse ByeDPI'ı başlatır, ardından `AppLauncher` ile uygulamayı favorinin argümanları ve `ByeDPIArguments.proxyEnvironment` ile açar; açılan örneği `SelfRestartWatcher`'a verir. Çalışan ciadpi harici ve `-G`'siz ise veya DNS zehirli bulunduysa durum mesajı uyarır (#15). Roblox (`KnownApps.robloxBundleID`) bizim sistem proxy'miz kapalıyken başlatılırsa durum mesajı, şifreyle girişteki güvenlik doğrulaması için Sistem Proxy'yi de açmayı hatırlatır (#13).
- `relaunchAfterSelfRestart`: İzlenen favori kendini proxy'siz yeniden başlattıysa 1,5 sn bekleyip `confirmRestart: false` ile yeniden açar ve `SelfRestartWatcher.recordRelaunch` ile döngü sınırına sayar. Yeni örneğin komut satırı (`ps -o args=`) argümanların hepsini içeriyorsa (`SelfRestartPolicy.commandLine`) dokunmaz (sınıra sayılmaz); ByeDPI çalışmıyorsa yalnızca uyarır.
- Bağlantı testi: `start()` ve `restart()` başarılı olunca `scheduleConnectionTest()` yalnızca 1080 örneğinde `ConnectionTester.shared.run` çağırır (testlerdeki örnekler ağa istek göndermez); ByeDPI durunca sonuçlar silinir. `runConnectionTest()` "Test Et" düğmesi içindir.
- `findCiadpiPath`: `Contents/Resources/bin/ciadpi` → geliştirmede `<repo>/byedpi/ciadpi`.

### Services/SystemProxyService.swift

"Bizim proxy" = herhangi bir ağ servisinde SOCKS **veya** güvenli web proxy'si (HTTPS) açık ve `127.0.0.1:1080`'i gösteriyor (`OurProxyState.detect`, saf ve testli; v1.1.0'ın yalnızca-SOCKS ayarı da algılanır). `refresh()` tüm servislerde `-getsocksfirewallproxy` ve `-getsecurewebproxy` okur (ikisinin çıktı biçimi aynıdır, `NetworkSetupParser.parseProxySettings`) ve `activeProxies`'i yayınlar; açılıştaki eski proxy kontrolü, durdurma/çökme/çıkışta otomatik kapatma, pencere ve menü çubuğu bunu kullanır. `enable()` birincil servisi `NetworkConfigService.resolvePrimaryService()` ile bulur (VPN/utun ise fiziksel servise düşer; yoksa `noActiveService`). Serviste başka bir sunucuyu gösteren açık SOCKS/HTTPS proxy varsa (`OurProxyState.foreignProxy`, saf ve testli) üzerine yazmaz, `foreignProxy` hatası verir. Aksi halde tek yetkili komutla (`enableCommand(services:)`) birincil serviste ve bizi gösteren yarım ayarı olan diğer servislerde SOCKS ve HTTPS proxy'yi ayarlayıp açar. Yetkili komut aynı root kabukta önce `lsof … -c ciadpi` ile dinleyiciyi doğrular, yoksa `SPLITWIRE_NO_LISTENER` ile çıkar (`noListener`). `disableAll()` bizim proxy'nin açık olduğu tüm servislerde yalnızca bizi gösteren türleri (SOCKS ve/veya HTTPS) tek parola penceresinde kapatır; başka sunucuya ayarlı kullanıcı proxy'sine dokunmaz. Düz web proxy'si (HTTP) asla ayarlanmaz (ciadpi `GET http://…` biçimli istekleri karşılayamaz) ve bypass listesi değiştirilmez. `hasIncompleteSetup`: bir serviste türlerden yalnızca biri açık ve aynı serviste kullanıcının kendi proxy'si (`hasForeignProxy`) açık değil (sayfada "Aç" yeniden etkinleşir; tek basışta tamamlanır). `isBusy` sürerken pencere ve menü çubuğunda Başlat/Durdur/preset devre dışıdır. `init(host:port:)` testler için enjekte edilebilir.

### Services/AppLauncher.swift

Uygulamayı `NSWorkspace.openApplication` ile argümanlar ve ortam değişkenleriyle (`OpenConfiguration.environment`, mevcut ortama eklenir; SplitWire sandbox'lı olmadığı için yok sayılmaz) açar (kabuk yok) ve başlatılan `NSRunningApplication`'ı döndürür (iptalde `nil`). Argüman ve ortam yalnızca yeni başlatılan örneğe iletildiğinden uygulama açıksa "Kapat ve Yeniden Başlat" önerir (`confirmRestart: false` ise sormadan kapatır; yalnızca kendi kendine yeniden başlatmada kullanılır).

- Kapatma uygulamanın "ailesine" uygulanır: uygulamanın çalışan örnekleri + `KnownApps.companionBundleIDs(of:)` yardımcıları (Roblox için menü çubuğu uygulaması). Uygulama kapalı, yalnızca yardımcı açıksa sormadan kapatılır; açık kalırsa Roblox'u `HTTPS_PROXY` olmadan yeniden açar (#13).
- `terminateFamily`: Aile kapalı kalana kadar açık olan her örneğe saniyede bir `terminate()` yineler (yeni açılan bir örnek açılışını bitirmeden gelen isteği kaçırabilir; Roblox ile yardımcısı birbirini ~1 sn içinde yeniden açar). Yardımcısı olan uygulamalarda aile boş görününce 1,5 sn bekleyip yeniden bakar; ancak hâlâ boşsa kapandı sayılır.
- Süre: `KnownApps.forceQuitsWithoutAsking(_:)` (Roblox) için 3 sn, ardından soru sormadan zorla kapatma (kullanıcı "Kapat ve Yeniden Başlat"ı zaten onayladı; oyun ilerlemesi sunucuda tutulur; yardımcı açık değilken kapatılan Roblox yalnızca penceresini kapatıp arka planda çalışmaya devam eder). Diğer uygulamalar için 8 sn, ardından "Zorla Kapat" sorusu. Zorla kapatma aynı döngüyle `forceTerminate()` ile 4 sn sürer; yine kapanmazsa `AppLaunchError.stillRunning`.

### Services/SelfRestartWatcher.swift

`NSWorkspace.didLaunchApplicationNotification` / `didTerminateApplicationNotification` bildirimlerini `SelfRestartTracker`'a iletir. `track(_:instance:)` Hızlı İşlemler'den açılan örneği izlemeye alır; `untrack(_:)` uygulamayı kendimiz kapatıp açmadan önce çağrılır (bizim kapatmamız yeniden başlatma sanılmasın, döngü olmasın) ve iptal halinde yeniden izlemek için PID'i döndürür. Karar çıkınca favori `currentFavorite` ile güncel listeden (`AppState.shared.favoriteApps`) id ile bulunur: favori silinmişse yeniden açılmaz, düzenlenmişse güncel argümanlar kullanılır. Yeni örnek hâlâ çalışıyorsa `onSelfRestart` çağrılır (#15). `recordRelaunch(_:)` gerçek bir otomatik yeniden açmadan sonra çağrılır ve döngü sınırına yalnızca bunlar sayılır.

Roblox'un yeniden açılmaları görülmez: Roblox'un Info.plist'inde `LSUIElement` = true olduğundan macOS onun için uygulama açıldı bildirimi göndermez. Bu yüzden Roblox için otomatik yeniden açma yoktur (rehber, tarayıcıdaki "Oyna" ile proxy'siz açılan Roblox'u kapatıp Hızlı İşlemler'den yeniden açmayı söyler). Discord'da davranış değişmedi (yeniden doğrulandı: argümansız yeniden açılan Discord yakalanıp proxy parametresi ve `HTTPS_PROXY` ile yeniden açıldı).

### Services/ConnectionTester.swift

- `ConnectionCheck.all`: `discordApp` (`https://discord.com/api/v9/gateway`), `discordUpdater` (`https://updates.discord.com/distributions/app/manifests/latest?…`, `tls12Only`), `roblox` (`https://clientsettings.roblox.com/v2/client-version/MacPlayer`).
- `ConnectionTester.run(host:port:args:)`: Her denetim için ayrı geçici `URLSession`; `connectionProxyDictionary` ile ByeDPI'ın HTTPS proxy'si (CONNECT), 10/15 sn zaman aşımı, önbellek yok, `tls12Only` için `tlsMaximumSupportedProtocolVersion = .TLSv12` (Discord'un güncelleyicisi gibi). Herhangi bir `HTTPURLResponse` başarı sayılır. Denetimler paralel çalışır; bu sırada yeni test başladıysa (`generation`) eski sonuç yazılmaz. `testedArgs`, sonuçların hangi argümanlara ait olduğunu tutar (yöntem değişince eski sonuç gösterilmez). `dnsPoisonedDuringTest`, teşhisin test anındaki DNS durumuna dayanmasını sağlar; DNS yeniden kontrol edilince (`lastChecked` değişince) `ConnectionTestView` testi yeniden çalıştırır.
- `ConnectionDiagnosis.evaluate` (saf, testli): hepsi geçti → `allReachable`; hepsi başarısız → DNS zehirliyse `dnsPoisoned`, değilse `allFailed`; yalnızca `discordUpdater` başarısız → `tls12Blocked` (Split 2'yi, zaten Split 2 ise Özel'de `-s 3 --tlsrec 1+s` önerir); diğerleri → `someFailed`.
- `ConnectionTestView` (ByeDPIView.swift) sonuçları **ByeDPI Durumu** bölümünde gösterir.

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

- `ByeDPIPresets.swift`: Sıralı preset tablosu (Fake yok), `defaultID` = "Split 2" (arayüzde "Split 2 (önerilen)" / "Split 2 (recommended)"), `standardID` = "Standart" (seçilebilir, artık varsayılan değil), `migrate` (eski `menuBarPreset` → `byedpiPreset`, bilinmeyen/kaldırılmış → Split 2), `migrateOldDefault` (v1.1.2 tek seferlik Standart → Split 2), `args(for:)` (bilinmeyen id → Split 2), `ByeDPIArguments` (tırnak destekli `tokenize`, `build` (`-i`/`-p`/`-G` ekler), `containsHTTPConnect`, `commandLineSupportsHTTPConnect`, `proxyEnvironment` (`HTTPS_PROXY`/`https_proxy` = `http://127.0.0.1:1080`, `NO_PROXY`/`no_proxy` = `localhost,127.0.0.1,::1`; `HTTP_PROXY`/`ALL_PROXY` bilerek yok: ciadpi düz HTTP proxy'si değildir), `displayString`).
- `SelfRestartPolicy.swift`: `SelfRestartPolicy` (`restartWindow` 30 sn, `relaunchPeriod` 10 dk içinde `maxRelaunches` 3, `isSelfRestart`, `canRelaunch`, `commandLine(_:containsAll:)`) ve `SelfRestartTracker` durum makinesi (izlenen örnekler; bundle id veya paket yolu eşleşmesi; kapanma/açılma bildirimleri hangi sırayla gelirse gelsin karar verir). Döngü sınırı için tarihleri yalnızca `recordRelaunch(_:at:)` ekler; karar (`decide()`) sayaca eklemez, böylece yeni örneğin argümanlarımızla açıldığı kararlar (Electron `app.relaunch()`) sınırı doldurmaz.
- `KnownApps.swift`: Hızlı İşlemler'de özel davranış gerektiren uygulamalar (#13): `robloxBundleID` (`com.roblox.RobloxPlayer`), `robloxMenuBarBundleID` (`com.roblox.RobloxPlayer.MenuBar`, `Roblox.app` içindeki `RobloxMenuBar.app`), `companionBundleIDs(of:)` (birlikte kapatılacak yardımcılar; Roblox → menü çubuğu uygulaması, diğerleri → boş), `forceQuitsWithoutAsking(_:)` (yalnızca Roblox).
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
| `byedpiPresetMigratedToSplit2` | v1.1.2'nin Standart → Split 2 geçişi yapıldı mı (bir kez) |
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
  → (yalnızca 1080) ConnectionTester.run arka planda
```

### Favori uygulama başlatma (#15, #13)

```
Hızlı İşlemler'de simge
  → ByeDPIService.launchFavoriteApp → ByeDPI kapalıysa start() + 0,3 sn
  → SelfRestartWatcher.untrack (bizim kapatmamız yeniden başlatma sanılmasın)
  → AppLauncher.launch(arguments: tokenize(customArgs),
                       environment: proxyEnvironment → HTTPS_PROXY/https_proxy=http://127.0.0.1:1080,
                                                       NO_PROXY/no_proxy=localhost,127.0.0.1,::1)
       → açıksa "Kapat ve Yeniden Başlat" (yalnızca yardımcı açıksa sorulmaz)
       → terminateFamily: uygulama + yardımcılar (Roblox: menü çubuğu uygulaması), geri gelenler yeniden kapatılır
            → Roblox 3 sn'de kapanmadı: sormadan zorla kapat | diğerleri 8 sn: "Zorla Kapat" sorusu
       → NSWorkspace.openApplication
  → SelfRestartWatcher.track(yeni örnek)
  → durum: başarılı (Roblox + Sistem Proxy kapalı: güvenlik doğrulaması hatırlatması)
           | uyarı (harici ciadpi -G'siz | DNS zehirli) | iptal (önceki örnek yeniden izlenir)
```

- `--proxy-server` yalnızca Chromium ağ katmanını etkiler. Discord'un macOS güncelleyicisi (`Resources/updater.node`, Rust reqwest, Security.framework TLS, en çok TLS 1.2) bu parametreyi kullanmaz; 0.0.419'dan önceki sürümler (reqwest 0.11.9) macOS sistem proxy'sini de okumaz, 0.0.419 ve sonrası (reqwest 0.12.28, SystemConfiguration) sistem HTTPS proxy'sini de okur; hepsi `HTTPS_PROXY`'yi okur. Discord'un açılış ekranı denetim başarılı olana kadar bekler (#15).
- Roblox (#13, Roblox kurulu bir Mac'te doğrulandı): macOS istemcisi (libcurl) `--proxy-server` parametresini ve macOS sistem proxy'sini kullanmaz ama `HTTPS_PROXY`'yi okur. `HTTPS_PROXY` ile açılınca tüm HTTPS trafiği (apis, auth, clientsettings (CDN), gamejoin, ecsv2, realtime-signalr, …) ByeDPI'dan geçer. Proxy'siz günlüklerde `SslConnectFail` (TLS sırasında bağlantı sıfırlanır, SNI engeli; ör. `ecsv2.roblox.com`) ve `TlsVerificationFail` (ad engelleme adresine çözülür) görülür ve giriş başarısız olur. Girişten sonra ByeDPI ile oyuna girildi (gamejoin, "Game join succeeded"). Oyun trafiği (UDP) proxy'den geçmez, doğrudan oyun sunucusuna gider; proxy ping eklemez (ping ölçülmedi). Yeniden girişte farklı sunucuya (farklı job id ve sunucu IP'si) bağlanıldı, yani sunucu değiştirmek çalışır.
- Şifreyle giriş: `auth.roblox.com/v2/login` "Challenge is required" döndürür; Roblox güvenlik doğrulamasını ("Security" ekranı, `https://www.roblox.com/challenge/cdn/hybrid`) gömülü bir macOS web görünümünde açar. Bu görünüm `HTTPS_PROXY`'yi değil yalnızca macOS sistem proxy'sini kullanır. Sistem proxy kapalıyken `www.roblox.com` SNI engeline takılır (TLS sırasında bağlantı sıfırlanır), ekran boş kalır ve giriş ilerlemez; sistem HTTPS proxy'si ByeDPI'ı gösterince doğrulama açıldı ve giriş tamamlandı. Captcha sağlayıcıları (Arkose Labs, hCaptcha) engelli değil. Bu yüzden şifreyle girişte Sistem Proxy de açılır; girişten sonra kapatılabilir (ekran yine boş kalırsa yeniden açılır).
- Menü çubuğu yardımcısı: `Roblox.app` içindeki `RobloxMenuBar.app` (`com.roblox.RobloxPlayer.MenuBar`) ile Roblox birbirini ~1 sn içinde yeniden açar; kapatılan Roblox `-launchToTray` ile tepsi modunda geri gelir ve yeni örnek ortamı onu açan süreçten alır. Yardımcı çalışmıyorsa Roblox'u kapatmak yalnızca penceresini kapatır, Roblox arka planda çalışmaya devam eder. `AppLauncher` bu yüzden aileyi birlikte kapatır, geri gelenleri yeniden kapatır ve 3 sn'de kapanmazsa sormadan zorla kapatır; ardından Roblox'u `HTTPS_PROXY` ile açar, onun başlattığı yardımcı da bu ortamı alır. Ölçüm: başka bir proxy ayarıyla açılmış Roblox + yardımcı 2,9 sn'de, penceresi kapatılmış (arka planda çalışan) Roblox 5,3 sn'de yenisiyle değiştirildi.
- Roblox kuruluysa (`KnownApps.robloxBundleID` veya `/Applications/Roblox.app`) ve favori değilse `RobloxGuideNote` "Roblox'u Hızlı İşlemler'e Ekle" düğmesini gösterir; düğme Roblox'u `--proxy-server` olmadan ekler (`customArgs` boş; Roblox bu parametreyi kullanmaz, `HTTPS_PROXY` yeterli). Rehberin adımları: önce DNS'i düzeltin (1.1.1.1 veya DoH profili); Roblox'u Hızlı İşlemler'e ekleyip her zaman oradan başlatın (açıksa menü çubuğu simgesiyle birlikte kapatılıp yeniden açılır); şifreyle girişte Sistem Proxy'yi de açın; oyunlara Roblox uygulamasının içinden girin (Roblox menü çubuğundan tamamen kapatıldıysa tarayıcıdaki "Oyna" onu proxy'siz açar). Sistem Proxy sayfası da Roblox'un kendisinin bu ayarı kullanmadığını, ama şifreyle girişteki güvenlik doğrulamasının kullandığını söyler.
- Bu ölçümler tek bir Mac'te, tek bir Türk İSS'sinde yapıldı (Roblox 0.745.0.7451137, macOS 27); başka İSS'lerde davranış farklı olabilir. İşe yaramazsa yedek yol WireGuard sekmesidir. Sonuçlar [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13) üzerinden bildirilebilir.

### Kendi kendine yeniden başlatma (#15)

```
Discord güncellemeyi kurar → eski örnek kapanır → launchd yeni sürümü argümansız/ortamsız açar (ölçüm: ~4 sn)
  → NSWorkspace didTerminate / didLaunch → SelfRestartTracker (sıra fark etmez)
  → aynı uygulama (bundle id veya paket yolu), farklı PID, ≤ 30 sn → karar
       (> 30 sn: kullanıcı kendisi açtı, izleme bırakılır)
  → canRelaunch: son 10 dk'da < 3 otomatik yeniden başlatma (yalnızca gerçekten yeniden açılanlar sayılır)
  → ByeDPIService.relaunchAfterSelfRestart
       → ByeDPI çalışmıyor: uyarı, dokunma
       → ps -o args= argümanların hepsini içeriyor (Electron app.relaunch): yeniden izle, dokunma (sınıra sayılmaz)
       → 1,5 sn bekle → AppLauncher.launch(confirmRestart: false) → track → recordRelaunch → bilgi mesajı
```

Roblox'un Info.plist'inde `LSUIElement` = true olduğundan onun için açılma bildirimi gelmez; bu akış Roblox için çalışmaz (bkz. Services/SelfRestartWatcher.swift).

### Bağlantı testi (#15)

```
start() / restart() başarılı (yalnızca port 1080) veya "Test Et"
  → ConnectionTester.run: 3 denetim paralel, her biri ephemeral URLSession
       HTTPS proxy = 127.0.0.1:1080 (CONNECT, ciadpi -G); discordUpdater: TLS ≤ 1.2
  → results + testedArgs yayınlanır → ConnectionTestView
  → ConnectionDiagnosis.evaluate(results, dnsPoisoned: DNSHealthChecker.lastResult.isPoisoned)
       allReachable | tls12Blocked | dnsPoisoned | allFailed | someFailed
ByeDPI durunca veya beklenmedik şekilde kapanınca → ConnectionTester.clear()
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

Testler sistem ayarlarına dokunmaz. Entegrasyon testleri gerçek ciadpi'yi `127.0.0.1:41873` üzerinde çalıştırır (sistem proxy servisi de bu porta bakar, gerçek 1080 ayarına dokunulmaz), her presetin yalnızca loopback'te dinlediğini ve aynı portun hem SOCKS5 hem HTTP CONNECT el sıkışmasını kabul ettiğini kontrol eder; ciadpi yoksa atlanır. Bağlantı testi yalnızca 1080'deki gerçek örnekte çalıştığı için testler ağa istek göndermez; kendi kendine yeniden başlatma (döngü sınırına yalnızca gerçek yeniden açmaların sayılması dahil), Roblox yardımcısı ve teşhis mantığı `SelfRestartTracker` / `KnownApps` / `ConnectionDiagnosis` üzerinden NSWorkspace ve ağ olmadan test edilir (`AppLaunchTests.swift`). Yukarıdaki Command Line Tools kısıtı `swift build` / `swift run` / `swift test` için de geçerlidir.

Xcode ile çalışmak için: `open Package.swift`.

---

## İlgili dosyalar

- [README.md](README.md): Genel bilgi, kurulum, sorun giderme (TR/EN)
- [KULLANIM.md](KULLANIM.md): Ayrıntılı kullanım kılavuzu
- [RELEASE_NOTES_v1.1.3.md](RELEASE_NOTES_v1.1.3.md): v1.1.3 değişiklikleri (ciadpi HTTP CONNECT hedef portunu `Host` yerine istek satırından okur; macOS URLSession/WebKit istemcileri, bağlantı testi ve Roblox giriş doğrulaması)
- [RELEASE_NOTES_v1.1.2.md](RELEASE_NOTES_v1.1.2.md): v1.1.2 değişiklikleri (#15: Discord güncelleme denetimi, `HTTPS_PROXY`, varsayılan Split 2, otomatik yeniden açma, bağlantı testi; #13: Roblox için Hızlı İşlemler yolu)
- [RELEASE_NOTES_v1.1.1.md](RELEASE_NOTES_v1.1.1.md): v1.1.1 değişiklikleri (#13: Roblox, SOCKS + HTTPS sistem proxy)
- [RELEASE_NOTES_v1.1.0.md](RELEASE_NOTES_v1.1.0.md): v1.1.0 değişiklikleri
- [LICENSE](LICENSE): MIT
