<p align="center">
  <img src="splitwire-logo-128.png" width="96" alt="SplitWire-Turkey logo">
</p>

<h1 align="center">SplitWire-Turkey (macOS)</h1>

<p align="center">
  Türkiye'deki DPI ve DNS engellerini (ör. Discord) aşmak için macOS menü çubuğu uygulaması.<br>
  A macOS menu bar app to get around DPI and DNS blocking in Türkiye (e.g. Discord).
</p>

<p align="center">
  <a href="#türkçe">Türkçe</a> · <a href="#english">English</a> ·
  <a href="https://github.com/a-mertdincer/SplitWire-Turkey-macOS/releases">Releases</a> ·
  <a href="KULLANIM.md">Kullanım kılavuzu</a> ·
  <a href="RELEASE_NOTES_v1.1.0.md">v1.1.0 notları</a>
</p>

---

## Türkçe

### Ne işe yarar?

- **ByeDPI (ciadpi):** Bu Mac'te yerel bir SOCKS5 proxy (`127.0.0.1:1080`) çalıştırır ve operatörün DPI (derin paket inceleme) engelini aşar. Proxy yalnızca bu bilgisayardan erişilebilir; ağdaki diğer cihazlara açık değildir.
- **Hızlı İşlemler:** Discord ve diğer Chromium/Electron uygulamalarını tek tıkla proxy ayarıyla başlatır. Uygulama zaten açıksa kapatıp yeniden başlatmayı önerir.
- **DNS engeli kontrolü:** Açılışta `discord.com` adresinin gerçek adrese mi yoksa engelleme sayfasına mı çözüldüğünü kontrol eder ve sorun varsa uyarır. Tek tıkla Cloudflare DNS (1.1.1.1) ayarı ve şifreli DNS (DoH) profili sunar.
- **Sistem Proxy (isteğe bağlı):** Proxy parametresini desteklemeyen uygulamalar (Safari vb.) için sistem genelinde SOCKS proxy ayarı. ByeDPI durunca veya uygulamadan çıkınca otomatik kapatılır.
- **WireGuard / Cloudflare WARP:** Tüm trafiği Cloudflare WARP üzerinden geçiren tünel (Homebrew `wireguard-tools` gerekir).
- **Menü çubuğu:** Başlat/durdur, DPI yöntemi seçimi, sistem proxy durumu. Dock simgesi gizlenebilir; arayüz Türkçe veya İngilizce.

### Gereksinimler

- macOS 13 Ventura veya üstü
- Apple Silicon **veya** Intel Mac (uygulama ve ciadpi evrensel/universal derlenir)
- Sistem ayarı değiştiren işlemler (DNS, sistem proxy, WireGuard) için yönetici parolası. ByeDPI'ın kendisi yönetici yetkisi istemez.
- Yalnızca WireGuard modu için: [Homebrew](https://brew.sh) ve `brew install wireguard-tools`

### Kurulum

1. [Releases](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/releases) sayfasından `SplitWire-Turkey-v1.1.0.zip` dosyasını indirip açın.
2. `SplitWire-Turkey.app` dosyasını **Uygulamalar** (Applications) klasörüne sürükleyin.
3. İlk açılış: Uygulama ad-hoc imzalıdır (Apple Developer ID / notarizasyon yok), bu yüzden macOS geliştiriciyi doğrulayamadığını söyler. Şunlardan birini yapın:
   - macOS 13–14: Uygulamaya sağ tıklayın (Control-tık) > **Aç** > **Aç**.
   - macOS 15 ve sonrası: Uygulamayı bir kez açmayı deneyin, uyarıyı kapatın, ardından **Sistem Ayarları > Gizlilik ve Güvenlik** bölümünün altındaki **Yine de Aç** düğmesine basın.
   - Ya da Terminal'de:
     ```bash
     xattr -dr com.apple.quarantine /Applications/SplitWire-Turkey.app
     ```

> v1.0.0'daki "SplitWire-Turkey hasar görmüş, Çöp Sepeti'ne taşıyın" hatası paketin hatalı imzalanmasından kaynaklanıyordu ve v1.1.0'da düzeltildi.

### Hızlı başlangıç: Discord

1. Uygulamayı açın (ByeDPI sekmesi açılır) ve **Başlat**'a basın. Menü çubuğundaki kalkan simgesinden de başlatabilirsiniz.
2. Üstte turuncu **"DNS engellemesi algılandı"** uyarısı görünüyorsa:
   - **DNS'i Cloudflare (1.1.1.1) Yap** düğmesine basın (yönetici parolası istenir).
   - Uyarı hâlâ duruyorsa operatörünüz DNS trafiğini yakalıyordur: **Şifreli DNS (DoH) Profili…** ile profili oluşturun ve Sistem Ayarları'ndan yükleyin (adımlar: [KULLANIM.md](KULLANIM.md#şifreli-dns-doh-profili)). Sonra **Tekrar Kontrol Et**'e basın.
3. **Hızlı İşlemler** bölümündeki **Discord** simgesine tıklayın (Discord varsayılan olarak eklidir; yoksa **+** ile `/Applications/Discord.app` seçin).
   - Discord zaten açıksa uygulama **Kapat ve Yeniden Başlat** önerir. Proxy ayarı yalnızca bu şekilde yeni başlatılan Discord'a uygulanır.
   - Discord'u Dock'tan veya Spotlight'tan açarsanız proxy kullanılmaz; her seferinde SplitWire üzerinden başlatın.
4. Hâlâ bağlanamıyorsanız başka bir DPI yöntemi seçin (aşağıya bakın). ByeDPI çalışıyorsa seçilen yöntemle otomatik yeniden başlar; yeni yöntem başlatılamazsa önceki yönteme döner.

### DPI yöntemleri (presetler)

Seçiminiz kaydedilir; ana pencere ve menü çubuğu her zaman aynı yöntemi gösterir. Çalışan yöntem ve ciadpi'ye giden tam parametreler **ByeDPI Durumu** bölümünde görünür.

| Yöntem | ciadpi parametreleri |
|---|---|
| Standart (varsayılan) | `-r 1+s` |
| Split 1 | `-s 1 --tlsrec 1+s` |
| Split 2 | `-s 2 --tlsrec 1+s` |
| Disorder | `--disorder 1 --auto=torst --tlsrec 1+s` |
| Disorder SNI | `-d 1+s --tlsrec 1+s` |
| OOB | `-o 1 --auto=torst` |
| OOB SNI | `-o 1+s --tlsrec 1+s` |
| Split + Disorder | `-s 1+s -d 3+s --tlsrec 1+s` |
| Özel (Custom) | Kendi parametreleriniz |

- Tüm yöntemlere `-i 127.0.0.1 -p 1080` otomatik eklenir (Özel parametrelerde `-i`/`-p` yazmadıysanız).
- **Fake presetleri kaldırıldı:** macOS için derlenen ciadpi sahte paket (fake) gönderemez (`FAKE_SUPPORT` yalnızca Linux/Windows). Daha önce Fake seçtiyseniz ayar Standart'a döner.
- Önce Standart'ı deneyin. Çoğu durumda asıl sorun DNS'tir; DNS düzeldikten sonra Standart genelde yeterlidir.

### Hangi uygulamalar proxy ayarını kullanır?

Hızlı İşlemler, uygulamayı `--proxy-server=socks5://127.0.0.1:1080` parametresiyle başlatır (uygulama başına düzenlenebilir).

| Uygulama türü | Ne yapmalı? |
|---|---|
| Chromium/Electron tabanlı (Discord, Chrome, Brave, Edge, Slack, Spotify…) | Hızlı İşlemler'den başlatın. |
| Safari ve macOS ağ ayarlarını kullanan uygulamalar | Parametreyi yok sayar; **Sistem Proxy**'yi açın. |
| Roblox, oyunlar ve kendi ağ yığınını kullanan uygulamalar | Parametreyi yok sayar, genellikle sistem SOCKS ayarını da kullanmaz; **WireGuard/WARP** kullanın. |
| Firefox | Kendi ayarı vardır: Ayarlar > Genel > Ağ Ayarları > Elle proxy yapılandırması: SOCKS sunucusu `127.0.0.1`, port `1080`, SOCKS v5; "SOCKS v5 kullanırken DNS'i proxy üzerinden yap" işaretli. |

### Sistem Proxy

**Hızlı İşlemler > Sistem Proxy > Aç**, birincil ağ servisinde (ör. Wi-Fi) SOCKS proxy'yi `127.0.0.1:1080` olarak açar.

- Yalnızca ByeDPI çalışırken açılabilir ve yalnızca ByeDPI çalışırken güvenlidir. Parola penceresi açıkken ByeDPI durursa proxy açılmaz.
- ByeDPI'ı **Durdur**duğunuzda, **Tümünü Zorla Kapat** kullandığınızda veya uygulamadan **çıktığınızda** otomatik kapatılır (yönetici parolası istenir; pencere nedenini yazar).
- ByeDPI beklenmedik şekilde durursa uygulama sizi uyarır ve proxy'yi kapatmayı önerir. Açılışta proxy açık ama ByeDPI çalışmıyorsa yine uyarır.
- ByeDPI'ı durdururken parola penceresini iptal ederseniz proxy açık kalır, internet çalışmaz ve uygulama uyarı gösterir: **Sistem Proxy > Kapat** ile kapatın veya ByeDPI'ı yeniden başlatın.
- Çıkışta proxy kapatılamazsa (parola iptal edildi veya hata) uygulama sorar: **Tekrar Dene**, **ByeDPI çalışsın, çık** (ByeDPI arka planda çalışmaya devam eder, internet çalışır) veya **Çıkma**. Oturum kapatma, yeniden başlatma ve bilgisayarı kapatmada soru sorulmaz; proxy açık kalmışsa SplitWire sonraki açılışta uyarır.
- Elle kapatma adımları [Sorun giderme](#sorun-giderme) bölümünde.

### WireGuard / Cloudflare WARP modu

ByeDPI ile çalışmayan uygulamalar (Roblox, oyunlar vb.) için alternatif.

1. Terminal'de: `brew install wireguard-tools` (wg-quick, wg, wireguard-go ve bash 4+ kurulur).
2. **WireGuard** sekmesi > **Kur ve Bağlan**. Uygulama:
   - `wgcf`'yi bulur (Homebrew veya `~/.local/bin`) ya da GitHub'dan bu Mac'in işlemcisine uygun sürümü indirip doğrular,
   - ücretsiz bir Cloudflare WARP hesabı ve WireGuard profili oluşturur (Cloudflare WARP koşulları kabul edilir),
   - WARP sunucusunun adresini şifreli DNS (DoH) ile çözüp yapılandırmaya IP olarak yazar,
   - tüneli kurar ve bağlar. Yönetici parolası bir kez sorulur.

Bilmeniz gerekenler:

- Bağlıyken bu Mac'in **TÜM** trafiği ve DNS sorguları Cloudflare WARP üzerinden geçer. macOS'ta WireGuard uygulama bazlı bölünmüş tünel (yalnızca Discord gibi) desteklemez.
- **Açılışta otomatik bağlan** varsayılan olarak kapalıdır. Kapalıyken tünel açılışta başlamaz; bilgisayar yeniden başladıktan sonra **Bağlan**'a basın (**Bağlan** ve **Bağlantıyı Kes** parola ister).
- Seçeneği açıp **Kur ve Bağlan** / **Yeniden Kur**'a basarsanız bir LaunchDaemon kurulur ve tünel her açılışta başlar; **Bağlantıyı Kes** yalnızca o oturum için kapatır. Güvenlik uyarısı: Bu durumda Homebrew'un `wg-quick`, `bash`, `wg` ve `wireguard-go` programları her açılışta parola sorulmadan root olarak çalışır; bu dosyaları kullanıcı hesabınız değiştirebildiği için hesabınızdaki kötü amaçlı bir program bunu yönetici yetkisi almak için kullanabilir. Seçenek kapalıyken **Yeniden Kur** var olan LaunchDaemon'ı kaldırır.
- WARP bağlıyken ByeDPI'a gerek yoktur.

### Menü çubuğu, Dock ve dil

- Pencereyi kapatmak uygulamayı kapatmaz; uygulama menü çubuğundaki kalkan simgesinde çalışmaya devam eder. Pencereyi geri getirmek için: kalkan simgesi > **Ana Pencereyi Göster**.
- **Dock simgesini gizle:** Pencerenin üst kısmındaki onay kutusu veya menü çubuğu menüsü.
- **Dil:** Pencerenin sağ üstündeki seçiciden Türkçe/English. Değişiklik pencereye ve menü çubuğuna anında uygulanır; macOS'un kendi menüleri (Gizle, Çık, Düzen, Pencere) bir sonraki açılışta seçilen dile geçer. İlk açılışta uygulama sistem dilinizi izler. Ayrıntılar: [KULLANIM.md](KULLANIM.md#dil-değiştirme).
- Tamamen çıkmak için: kalkan simgesi > **Çıkış** (veya ⌘Q). Çıkışta açıksa önce sistem proxy kapatılır, sonra ciadpi durdurulur (kapatılamazsa uygulama ne yapılacağını sorar; bkz. [Sistem Proxy](#sistem-proxy)).

### Sorun giderme

**Discord açılmıyor / "update failed" (DNS zehirlenmesi)**
Bazı operatörlerin DNS sunucuları `discord.com` için gerçek adres yerine engelleme sayfası adresi (`195.175.254.2`) döndürür. ciadpi hedef adresleri sistem DNS'i ile çözdüğü için DPI aşılsa bile bağlantı engelleme sayfasına gider. Çözüm:
1. DNS'i Cloudflare (1.1.1.1) yapın (uyarıdaki düğme veya **Ağ Ayarları** sekmesi).
2. Uyarı sürüyorsa operatörünüz 53. port DNS trafiğini yakalıyordur: DoH profilini yükleyin ya da WireGuard/WARP kullanın.
3. Discord'u SplitWire'dan **yeniden başlatın**.

Test için (ByeDPI çalışırken):
```bash
curl -I --socks5-hostname 127.0.0.1:1080 https://discord.com
```

**"Port 1080 kullanımda"**
- Önceki oturumdan kalmış bir ciadpi varsa uygulama **Süreçleri Kapat ve Tekrar Dene** seçeneğini sunar.
- Başka bir program kullanıyorsa hata mesajı programın adını ve PID'sini gösterir; o programı kapatın.
- Menü çubuğu veya Hızlı İşlemler > **Tümünü Zorla Kapat** tüm ciadpi süreçlerini sonlandırır.
- Elle: `lsof -nP -iTCP:1080 -sTCP:LISTEN` ile kontrol edin, `pkill -9 -x ciadpi` ile kapatın (ciadpi normal `kill` sinyalini yok sayar).

**Proxy açık kaldı, internet çalışmıyor**
1. Önce SplitWire'ı açın: Açılışta durumu algılar ve **Sistem Proxy'yi Kapat** seçeneği sunar.
2. Elle: **Sistem Ayarları > Ağ >** (Wi-Fi veya Ethernet) **> Ayrıntılar… > Proxy'ler** > **SOCKS proxy**'yi kapatın > **Tamam**.
3. Terminal ile: `networksetup -listallnetworkservices` ile servis adını bulun, sonra:
   ```bash
   sudo networksetup -setsocksfirewallproxystate "Wi-Fi" off
   ```

**WireGuard kurulumu başarısız**
- "wgcf: line 1: Not: command not found": v1.0.0'ın indirdiği bozuk dosya. v1.1.0 bunu algılar ve kurulumda otomatik yeniden indirir.
- "WireGuard araçları gerekli": `brew install wireguard-tools` çalıştırın, ardından tekrar deneyin.
- Kurulum ve bağlantı hataları WireGuard sekmesinde gösterilir. Açılışta otomatik bağlanma günlüğü (yalnızca bu seçenek açıksa): `/var/log/splitwire-wireguard.log`

Daha fazlası: [KULLANIM.md](KULLANIM.md).

### Kaynaktan derleme

Gereksinimler: macOS ve tam **Xcode** 15+ (Swift 5.9+). Yalnızca Command Line Tools yetmez: Yeni SDK'larda (ör. macOS 27 SDK) SwiftUI'nin `@State`'i bir makrodur ve Command Line Tools `SwiftUIMacros` eklentisini (`libSwiftUIMacros`) içermez. `build.sh` bu durumu derlemeden önce algılayıp durur. Xcode kuramıyorsanız daha eski bir SDK ile derleyin: `SDKROOT=$(xcrun --sdk macosx26.5 --show-sdk-path) ./build.sh` (ayrıntı: `./build.sh --help`).

```bash
git clone https://github.com/a-mertdincer/SplitWire-Turkey-macOS.git
cd SplitWire-Turkey-macOS

./build.sh                     # evrensel sürüm: SplitWire-Turkey.app + dist/SplitWire-Turkey-v1.1.0.zip (+ .sha256)
./build.sh --arch-native       # hızlı geliştirme derlemesi (yalnızca bu Mac'in mimarisi, zip yok)
./build.sh 1.1.0 --skip-zip    # .app'i derle, imzala ve doğrula; zip oluşturma
./build.sh --clean             # önce .build ve build/ klasörlerini sil
```

- Ortam değişkenleri: `VERSION`, `BUILD_NUMBER` (varsayılan: commit sayısı), `SCRATCH_PATH` (varsayılan: `.build`), `ALLOW_DIRTY`, `SDKROOT`.
- `build.sh`, ciadpi'yi `byedpi/` klasöründeki kaynaklardan (ByeDPI v17.3) derler, uygulamayı içten dışa ad-hoc imzalar ve `scripts/verify-app.sh` ile doğrular.
- Sürüm zip'i yalnızca commit'lenmiş kaynaktan üretilir: Derleme girdilerinde (`Package.swift`, `Sources/`, `byedpi/`, `scripts/`, `build.sh`, `AppIcon.icns`) commit'lenmemiş değişiklik varsa `build.sh` zip oluşturmayı reddeder (`--skip-zip` veya `ALLOW_DIRTY=1` ile geçilir). HEAD `v<VERSION>` etiketli değilse uyarır.
- Derlenen commit Info.plist'e `SWGitCommit` olarak yazılır (değişiklik varsa `-dirty` ekli) ve Hakkında'da derleme numarasının yanında görünür, ör. `5 (fe99aaa)`.

Geliştirme:

```bash
scripts/build-ciadpi.sh --arch-native   # byedpi/ciadpi oluşturur (swift run / swift test bunu kullanır)
swift run
swift test                              # entegrasyon testleri ciadpi'yi 127.0.0.1'de özel bir portta çalıştırır;
                                        # byedpi/ciadpi yoksa atlanır. Sistem ayarlarına dokunmaz.
scripts/verify-app.sh SplitWire-Turkey.app            # veya dist/...zip
```

Proje yapısı: [PROJE-YAPISI.md](PROJE-YAPISI.md).

### Emeği geçenler

- Orijinal [SplitWire-Turkey](https://github.com/cagritaskn/SplitWire-Turkey) (Windows): Çağrı Taşkın ([@cagritaskn](https://github.com/cagritaskn))
- [ByeDPI](https://github.com/hufrea/byedpi) (ciadpi): hufrea. Kaynak kodu `byedpi/` klasöründe, kendi MIT lisansıyla.
- [wgcf](https://github.com/ViRb3/wgcf): ViRb3
- [WireGuard](https://www.wireguard.com) (wireguard-tools, wireguard-go)
- macOS uyarlaması: Mert Dinçer ([@a-mertdincer](https://github.com/a-mertdincer))

### Lisans

MIT. Ayrıntılar için [LICENSE](LICENSE). Sorular ve hata bildirimleri: [Issues](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues).

---

## English

### What it does

- **ByeDPI (ciadpi):** Runs a local SOCKS5 proxy on `127.0.0.1:1080` that gets around your ISP's DPI (deep packet inspection) blocking. The proxy is reachable from this Mac only, not from other devices on your network.
- **Quick actions:** Launches Discord and other Chromium/Electron apps through the proxy with one click. If the app is already running, it offers to quit and relaunch it.
- **DNS blocking check:** At launch, checks whether `discord.com` resolves to its real address or to a block page, and warns you if it doesn't. Offers one-click Cloudflare DNS (1.1.1.1) and an encrypted DNS (DoH) profile.
- **System proxy (optional):** A system-wide SOCKS proxy for apps that ignore the proxy flag (Safari, etc.). It is turned off automatically when ByeDPI stops or you quit the app.
- **WireGuard / Cloudflare WARP:** A tunnel that sends all traffic through Cloudflare WARP (requires Homebrew `wireguard-tools`).
- **Menu bar:** Start/stop, DPI method selection, system proxy status. The Dock icon can be hidden; the interface is available in Turkish and English.

### Requirements

- macOS 13 Ventura or later
- Apple Silicon **or** Intel Mac (the app and ciadpi are universal binaries)
- Your administrator password for actions that change system settings (DNS, system proxy, WireGuard). ByeDPI itself does not need admin rights.
- WireGuard mode only: [Homebrew](https://brew.sh) and `brew install wireguard-tools`

### Installation

1. Download `SplitWire-Turkey-v1.1.0.zip` from [Releases](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/releases) and unzip it.
2. Drag `SplitWire-Turkey.app` into your **Applications** folder.
3. First launch: the app is signed ad-hoc (no Apple Developer ID / notarization), so macOS says it can't verify the developer. Do one of the following:
   - macOS 13–14: right-click (Control-click) the app > **Open** > **Open**.
   - macOS 15 and later: try to open the app once, dismiss the warning, then click **Open Anyway** at the bottom of **System Settings > Privacy & Security**.
   - Or in Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/SplitWire-Turkey.app
     ```

> The "SplitWire-Turkey is damaged and can't be opened" error in v1.0.0 was caused by an improperly signed bundle and is fixed in v1.1.0.

### Quick start: Discord

1. Open the app (it opens on the ByeDPI tab) and click **Start**. You can also start it from the shield icon in the menu bar.
2. If an orange **"DNS blocking detected"** banner appears:
   - Click **Use Cloudflare DNS (1.1.1.1)** (asks for your administrator password).
   - If the banner stays, your ISP is intercepting DNS traffic: use **Encrypted DNS (DoH) profile…** to create the profile and install it in System Settings (steps in [KULLANIM.md](KULLANIM.md#şifreli-dns-doh-profili), Turkish). Then click **Check again**.
3. Click the **Discord** icon under **Quick actions** (Discord is added by default; otherwise click **+** and choose `/Applications/Discord.app`).
   - If Discord is already running, the app offers **Quit and relaunch**. The proxy setting only applies to a Discord instance started this way.
   - If you open Discord from the Dock or Spotlight, it won't use the proxy; always launch it from SplitWire.
4. Still can't connect? Choose another DPI method (see below). If ByeDPI is running, it restarts with the new method automatically; if the new method fails to start, it goes back to the previous one.

### DPI methods (presets)

Your choice is saved, and the main window and menu bar always show the same method. The active method and the exact ciadpi arguments are shown under **ByeDPI status**.

| Method | ciadpi arguments |
|---|---|
| Standard (default; stored as "Standart") | `-r 1+s` |
| Split 1 | `-s 1 --tlsrec 1+s` |
| Split 2 | `-s 2 --tlsrec 1+s` |
| Disorder | `--disorder 1 --auto=torst --tlsrec 1+s` |
| Disorder SNI | `-d 1+s --tlsrec 1+s` |
| OOB | `-o 1 --auto=torst` |
| OOB SNI | `-o 1+s --tlsrec 1+s` |
| Split + Disorder | `-s 1+s -d 3+s --tlsrec 1+s` |
| Custom | Your own arguments |

- `-i 127.0.0.1 -p 1080` is added automatically (unless your Custom arguments set `-i`/`-p`).
- **Fake presets were removed:** ciadpi built for macOS can't send fake packets (`FAKE_SUPPORT` is Linux/Windows only). If you had a Fake preset selected, it falls back to Standard.
- Try Standard first. Most of the time the real problem is DNS; once DNS is fixed, Standard is usually enough.

### Which apps honor the proxy setting?

Quick actions launch the app with `--proxy-server=socks5://127.0.0.1:1080` (editable per app).

| App type | What to do |
|---|---|
| Chromium/Electron based (Discord, Chrome, Brave, Edge, Slack, Spotify…) | Launch it from Quick actions. |
| Safari and apps that use macOS network settings | Ignore the flag; turn on **System proxy**. |
| Roblox, games and apps with their own network stack | Ignore the flag and usually the system SOCKS setting too; use **WireGuard/WARP**. |
| Firefox | Has its own setting: Settings > General > Network Settings > Manual proxy configuration: SOCKS host `127.0.0.1`, port `1080`, SOCKS v5, with "Proxy DNS when using SOCKS v5" checked. |

### System proxy

**Quick actions > System proxy > Turn on** sets the SOCKS proxy of your primary network service (e.g. Wi-Fi) to `127.0.0.1:1080`.

- It can only be turned on while ByeDPI is running, and it is only safe while ByeDPI is running. If ByeDPI stops while the password prompt is open, the proxy is not turned on.
- It is turned off automatically when you **Stop** ByeDPI, use **Force stop all**, or **quit** the app (your administrator password is required; the prompt says why).
- If ByeDPI stops unexpectedly, the app warns you and offers to turn the proxy off. At launch, it also warns you if the proxy is on but ByeDPI isn't running.
- If you cancel the password prompt while stopping ByeDPI, the proxy stays on, your internet won't work, and the app shows a warning: turn it off with **System proxy > Turn off** or start ByeDPI again.
- If the proxy can't be turned off when you quit (password cancelled or an error), the app asks: **Try again**, **Quit, keep ByeDPI running** (ByeDPI keeps running in the background, so your internet keeps working) or **Don't quit**. There is no prompt on log out, restart or shut down; if the proxy was left on, SplitWire warns you the next time it opens.
- To turn it off manually, see [Troubleshooting](#troubleshooting).

### WireGuard / Cloudflare WARP mode

An alternative for apps that don't work with ByeDPI (Roblox, games, etc.).

1. In Terminal: `brew install wireguard-tools` (installs wg-quick, wg, wireguard-go and bash 4+).
2. **WireGuard** tab > **Install and connect**. The app:
   - finds `wgcf` (Homebrew or `~/.local/bin`) or downloads and verifies the right build for this Mac's processor from GitHub,
   - creates a free Cloudflare WARP account and WireGuard profile (accepting Cloudflare WARP's terms),
   - resolves the WARP server address over encrypted DNS (DoH) and writes it into the config as an IP address,
   - sets up and connects the tunnel. You are asked for your administrator password once.

Good to know:

- While connected, **ALL** of this Mac's traffic and DNS queries go through Cloudflare WARP. On macOS, WireGuard does not support per-app split tunnelling (e.g. Discord only).
- **Connect automatically at startup** is off by default. While it is off, the tunnel doesn't start at boot; click **Connect** after restarting the computer (**Connect** and **Disconnect** ask for your password).
- If you turn it on and click **Install and connect** / **Reinstall**, a LaunchDaemon is installed and the tunnel starts at every boot; **Disconnect** then only turns it off for the current session. Security warning: Homebrew's `wg-quick`, `bash`, `wg` and `wireguard-go` then run as root at every boot without a password prompt. Your user account can modify these files, so malware running in your account could use this to gain administrator rights. With the option off, **Reinstall** removes an existing LaunchDaemon.
- ByeDPI isn't needed while WARP is connected.

### Menu bar, Dock and language

- Closing the window doesn't quit the app; it keeps running from the shield icon in the menu bar. To bring the window back: shield icon > **Show main window**.
- **Hide Dock icon:** checkbox at the top of the window, or in the menu bar menu.
- **Language:** Türkçe/English picker at the top right of the window. The change applies to the window and the menu bar immediately; macOS's own menus (Hide, Quit, Edit, Window) switch the next time the app starts. On first launch the app follows your system language. Details (Turkish): [KULLANIM.md](KULLANIM.md#dil-değiştirme).
- To quit completely: shield icon > **Quit** (or ⌘Q). Quitting first turns off the system proxy if it is on, then stops ciadpi (if the proxy can't be turned off, the app asks what to do; see [System proxy](#system-proxy)).

### Troubleshooting

**Discord doesn't load / "update failed" (DNS poisoning)**
Some ISPs' DNS servers return a block-page address (`195.175.254.2`) instead of the real address for `discord.com`. ciadpi resolves target hosts with the system DNS, so even with DPI bypassed the connection goes to the block page. Fix:
1. Set DNS to Cloudflare (1.1.1.1) (button in the banner, or the **Network** tab).
2. If the warning persists, your ISP intercepts DNS on port 53: install the DoH profile or use WireGuard/WARP.
3. **Relaunch** Discord from SplitWire.

To test (while ByeDPI is running):
```bash
curl -I --socks5-hostname 127.0.0.1:1080 https://discord.com
```

**"Port 1080 is in use"**
- If a ciadpi from a previous session is still running, the app offers **Stop processes and retry**.
- If another program uses the port, the error shows its name and PID; quit that program.
- Menu bar or Quick actions > **Force stop all** kills every ciadpi process.
- Manually: check with `lsof -nP -iTCP:1080 -sTCP:LISTEN` and stop it with `pkill -9 -x ciadpi` (ciadpi ignores a normal `kill`).

**The proxy stayed on and the internet doesn't work**
1. Open SplitWire first: at launch it detects this and offers **Turn off system proxy**.
2. Manually: **System Settings > Network >** (Wi-Fi or Ethernet) **> Details… > Proxies** > turn off **SOCKS proxy** > **OK**.
3. In Terminal: find the service name with `networksetup -listallnetworkservices`, then:
   ```bash
   sudo networksetup -setsocksfirewallproxystate "Wi-Fi" off
   ```

**WireGuard setup fails**
- "wgcf: line 1: Not: command not found": the broken file downloaded by v1.0.0. v1.1.0 detects it and downloads wgcf again during setup.
- "WireGuard tools required": run `brew install wireguard-tools`, then try again.
- Setup and connection errors are shown in the WireGuard tab. Start-at-boot log (only if that option is on): `/var/log/splitwire-wireguard.log`

### Build from source

Requirements: macOS and full **Xcode** 15+ (Swift 5.9+). The Command Line Tools alone are not enough: in newer SDKs (e.g. the macOS 27 SDK) SwiftUI's `@State` is a macro, and the Command Line Tools don't ship the `SwiftUIMacros` plugin (`libSwiftUIMacros`). `build.sh` detects this before building and stops. If you can't install Xcode, build against an older SDK: `SDKROOT=$(xcrun --sdk macosx26.5 --show-sdk-path) ./build.sh` (see `./build.sh --help`).

```bash
git clone https://github.com/a-mertdincer/SplitWire-Turkey-macOS.git
cd SplitWire-Turkey-macOS

./build.sh                     # universal release: SplitWire-Turkey.app + dist/SplitWire-Turkey-v1.1.0.zip (+ .sha256)
./build.sh --arch-native       # fast dev build (this Mac's architecture only, no zip)
./build.sh 1.1.0 --skip-zip    # build, sign and verify the .app without the zip
./build.sh --clean             # delete .build and build/ first
```

- Environment variables: `VERSION`, `BUILD_NUMBER` (default: commit count), `SCRATCH_PATH` (default: `.build`), `ALLOW_DIRTY`, `SDKROOT`.
- `build.sh` compiles ciadpi from the vendored sources in `byedpi/` (ByeDPI v17.3), signs the app ad-hoc inside-out, and verifies it with `scripts/verify-app.sh`.
- The release zip is only built from committed sources: if the build inputs (`Package.swift`, `Sources/`, `byedpi/`, `scripts/`, `build.sh`, `AppIcon.icns`) have uncommitted changes, `build.sh` refuses to create the zip (override with `--skip-zip` or `ALLOW_DIRTY=1`). It warns if HEAD isn't tagged `v<VERSION>`.
- The commit is written into Info.plist as `SWGitCommit` (with `-dirty` if there were changes) and shown next to the build number in About, e.g. `5 (fe99aaa)`.

Development:

```bash
scripts/build-ciadpi.sh --arch-native   # builds byedpi/ciadpi (used by swift run / swift test)
swift run
swift test                              # integration tests run ciadpi on a private port on 127.0.0.1;
                                        # skipped if byedpi/ciadpi is missing. No system settings are touched.
scripts/verify-app.sh SplitWire-Turkey.app            # or dist/...zip
```

Project layout (Turkish): [PROJE-YAPISI.md](PROJE-YAPISI.md).

### Credits

- Original [SplitWire-Turkey](https://github.com/cagritaskn/SplitWire-Turkey) (Windows) by Çağrı Taşkın ([@cagritaskn](https://github.com/cagritaskn))
- [ByeDPI](https://github.com/hufrea/byedpi) (ciadpi) by hufrea. Sources vendored in `byedpi/` under their own MIT license.
- [wgcf](https://github.com/ViRb3/wgcf) by ViRb3
- [WireGuard](https://www.wireguard.com) (wireguard-tools, wireguard-go)
- macOS port by Mert Dinçer ([@a-mertdincer](https://github.com/a-mertdincer))

### License

MIT. See [LICENSE](LICENSE). Questions and bug reports: [Issues](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues).
