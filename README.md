<p align="center">
  <img src="splitwire-logo-128.png" width="96" alt="SplitWire-Turkey logo">
</p>

<h1 align="center">SplitWire-Turkey (macOS)</h1>

<p align="center">
  Türkiye'deki DPI ve DNS engellerini (ör. Discord, Roblox) aşmak için macOS menü çubuğu uygulaması.<br>
  A macOS menu bar app to get around DPI and DNS blocking in Türkiye (e.g. Discord, Roblox).
</p>

<p align="center">
  <a href="#türkçe">Türkçe</a> · <a href="#english">English</a> ·
  <a href="https://github.com/a-mertdincer/SplitWire-Turkey-macOS/releases">Releases</a> ·
  <a href="KULLANIM.md">Kullanım kılavuzu</a> ·
  <a href="RELEASE_NOTES_v1.1.3.md">v1.1.3 notları</a> ·
  <a href="RELEASE_NOTES_v1.1.2.md">v1.1.2</a> ·
  <a href="RELEASE_NOTES_v1.1.1.md">v1.1.1</a> ·
  <a href="RELEASE_NOTES_v1.1.0.md">v1.1.0</a>
</p>

---

## Türkçe

### Ne işe yarar?

- **ByeDPI (ciadpi):** Bu Mac'te yerel bir proxy (`127.0.0.1:1080`) çalıştırır ve operatörün DPI (derin paket inceleme) engelini aşar. Aynı port hem SOCKS5 hem HTTPS (HTTP CONNECT) bağlantılarını kabul eder. Proxy yalnızca bu bilgisayardan erişilebilir; ağdaki diğer cihazlara açık değildir.
- **Hızlı İşlemler:** Discord, Roblox ve diğer uygulamaları tek tıkla ByeDPI üzerinden başlatır: Chromium/Electron için `--proxy-server` parametresi, Discord'un güncelleme denetimi ve Roblox gibi `HTTPS_PROXY` okuyan programlar için ortam değişkeni verilir. Uygulama zaten açıksa kapatıp yeniden başlatmayı önerir. Buradan açılan bir uygulama kendini proxy'siz yeniden başlatırsa (ör. Discord güncellemeden sonra) SplitWire onu ByeDPI ile yeniden açar (Roblox hariç: macOS Roblox'un açılışını bildirmez; bkz. [Roblox](#roblox)).
- **Bağlantı testi:** ByeDPI başlayınca ve yöntem değişince ByeDPI üzerinden Discord'a, Discord'un güncelleme denetimine (TLS 1.2) ve Roblox'a bağlanmayı dener. Sonuç **ByeDPI Durumu** bölümünde görünür ve sorunun DNS'te mi yoksa yöntemde mi olduğunu söyler.
- **DNS engeli kontrolü:** Açılışta Discord (`discord.com`, `gateway.discord.gg`) adreslerinin gerçek adrese mi yoksa engelleme sayfasına mı çözüldüğünü şifreli DNS ile karşılaştırarak kontrol eder; Roblox (`www.roblox.com`) için bilinen engelleme adreslerine ve Discord'un zehirli bulunduğu adrese bakar. Hangi servislerin etkilendiğini söyleyerek uyarır. Tek tıkla Cloudflare DNS (1.1.1.1) ayarı ve şifreli DNS (DoH) profili sunar.
- **Sistem Proxy (isteğe bağlı):** macOS proxy ayarlarını kullanan uygulamalar (ör. Safari) için sistem genelinde SOCKS ve HTTPS proxy ayarı. Roblox'un kendisi bu ayarı kullanmaz, ama şifreyle girişteki güvenlik doğrulaması kullanır. ByeDPI durunca veya uygulamadan çıkınca otomatik kapatılır.
- **WireGuard / Cloudflare WARP:** Tüm trafiği Cloudflare WARP üzerinden geçiren tünel (Homebrew `wireguard-tools` gerekir).
- **Menü çubuğu:** Başlat/durdur, DPI yöntemi seçimi, sistem proxy durumu. Dock simgesi gizlenebilir; arayüz Türkçe veya İngilizce.

### Gereksinimler

- macOS 13 Ventura veya üstü
- Apple Silicon **veya** Intel Mac (uygulama ve ciadpi evrensel/universal derlenir)
- Sistem ayarı değiştiren işlemler (DNS, sistem proxy, WireGuard) için yönetici parolası. ByeDPI'ın kendisi yönetici yetkisi istemez.
- Yalnızca WireGuard modu için: [Homebrew](https://brew.sh) ve `brew install wireguard-tools`

### Kurulum

1. [Releases](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/releases) sayfasından `SplitWire-Turkey-v1.1.3.zip` dosyasını indirip açın.
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
   - SplitWire Discord'u `--proxy-server` parametresi ve `HTTPS_PROXY` ortam değişkeniyle başlatır. İkisi de gerekir: Discord açılışta güncelleme denetimi yapar ve bu denetim başarılı olmadan "Checking for updates…" ekranında kalır. Denetim `--proxy-server` parametresini kullanmaz; 0.0.419'dan önceki sürümleri macOS sistem proxy'sini de okumaz; hepsi `HTTPS_PROXY`'yi okur ([#15](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/15)).
   - Discord zaten açıksa uygulama **Kapat ve Yeniden Başlat** önerir. Proxy ayarı yalnızca bu şekilde yeni başlatılan Discord'a uygulanır.
   - Discord'u Dock'tan veya Spotlight'tan açarsanız proxy parametresi ve `HTTPS_PROXY` verilmez; her seferinde SplitWire üzerinden başlatın. (Discord 0.0.419 ve sonrasında, ByeDPI çalışırken [Sistem Proxy](#sistem-proxy) açıksa Dock'tan açılan Discord da ByeDPI'dan geçer.)
   - Discord güncellemeyi kurup kendini proxy'siz yeniden başlatırsa SplitWire bunu algılar ve Discord'u ByeDPI ile yeniden açar (10 dakikada en çok 3 kez).
4. **ByeDPI Durumu** bölümündeki bağlantı testine bakın: sorunun DNS'te mi yoksa yöntemde mi olduğunu söyler. Gerekirse başka bir DPI yöntemi seçin (aşağıya bakın). ByeDPI çalışıyorsa seçilen yöntemle otomatik yeniden başlar; yeni yöntem başlatılamazsa önceki yönteme döner.

### DPI yöntemleri (presetler)

Seçiminiz kaydedilir; ana pencere ve menü çubuğu her zaman aynı yöntemi gösterir. Çalışan yöntem ve ciadpi'ye giden tam parametreler **ByeDPI Durumu** bölümünde görünür.

| Yöntem | ciadpi parametreleri |
|---|---|
| Standart | `-r 1+s` |
| Split 1 | `-s 1 --tlsrec 1+s` |
| Split 2 (önerilen, varsayılan) | `-s 2 --tlsrec 1+s` |
| Disorder | `--disorder 1 --auto=torst --tlsrec 1+s` |
| Disorder SNI | `-d 1+s --tlsrec 1+s` |
| OOB | `-o 1 --auto=torst` |
| OOB SNI | `-o 1+s --tlsrec 1+s` |
| Split + Disorder | `-s 1+s -d 3+s --tlsrec 1+s` |
| Özel (Custom) | Kendi parametreleriniz |

- Tüm yöntemlere `-i 127.0.0.1 -p 1080 -G` otomatik eklenir (Özel parametrelerde `-i`/`-p`/`-G` yazmadıysanız). `-G` (`--http-connect`), aynı portun SOCKS5'in yanında HTTP CONNECT isteklerini de kabul etmesini sağlar; sistem HTTPS proxy'si ve Hızlı İşlemler'in verdiği `HTTPS_PROXY` bunu kullanır. ciadpi düz HTTP proxy isteklerini (`GET http://…`) karşılayamaz, bu yüzden düz web proxy'si (HTTP) asla ayarlanmaz.
- **Neden Split 2:** Discord'un güncelleme denetimi en çok TLS 1.2 kullanır. TLS 1.2'de sunucu sertifikası şifresiz gittiği için operatörün DPI'ı bağlantıyı sertifikadan tanıyıp kesebilir. 28 Ekim 2026'da bir Türk operatöründe yapılan ölçümde Split 2 dışındaki tüm hazır yöntemler TLS 1.3'ü geçirdi, ama TLS 1.2 bağlantısı sunucunun ilk 1400 baytından sonra kesildi. Split 2 (ve `-s N` ile N≥2 olan parametreler) ikisini de geçirdi: `discord.com`, `updates.discord.com`, `gateway.discord.gg`, `cdn.discordapp.com`, `discordapp.com`, `www.roblox.com`, `clientsettings.roblox.com`, `apis.roblox.com`, `auth.roblox.com`. Ölçüm tek operatörde yapıldı; bağlantı testinde "Discord güncelleme denetimi" başarısızsa başka yöntemleri deneyin ve sonucu bildirin.
- **Standart artık varsayılan değil:** Seçilebilir, ama ölçümde yalnızca TLS 1.3'ü geçirdi. v1.1.1'den yükseltirken yönteminiz Standart ise bir kez Split 2'ye geçirilirsiniz ve uygulama bunu durum mesajında söyler; Standart'ı yeniden seçerseniz bir daha değiştirilmez.
- **Fake presetleri kaldırıldı:** macOS için derlenen ciadpi sahte paket (fake) gönderemez (`FAKE_SUPPORT` yalnızca Linux/Windows). Daha önce Fake veya bilinmeyen bir yöntem seçtiyseniz ayar Split 2'ye döner.
- Önce Split 2'yi deneyin. Çoğu durumda asıl sorun DNS'tir: önce DNS uyarısını giderin, sonra bağlantı testine bakın.

### Hangi uygulamalar proxy ayarını kullanır?

Hızlı İşlemler, uygulamayı `--proxy-server=socks5://127.0.0.1:1080` parametresiyle (uygulama başına düzenlenebilir) ve `HTTPS_PROXY=http://127.0.0.1:1080` ortam değişkeniyle başlatır (ayrıca `https_proxy`, `NO_PROXY` / `no_proxy` = `localhost,127.0.0.1,::1`). `HTTP_PROXY` ve `ALL_PROXY` bilerek verilmez: ciadpi düz HTTP proxy'si değildir, şifresiz HTTP istekleri bozulurdu. Ortam değişkenleri uygulamanın alt süreçlerine de geçer; ByeDPI'ı durdurduğunuzda bu uygulamaları kapatıp normal şekilde açın.

| Uygulama türü | Ne yapmalı? |
|---|---|
| Discord | Hızlı İşlemler'den başlatın. Pencereler proxy parametresini, açılıştaki güncelleme denetimi `HTTPS_PROXY`'yi kullanır; ikisi de verilir ([#15](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/15)). |
| Diğer Chromium/Electron tabanlı uygulamalar (Chrome, Brave, Edge, Slack, Spotify…) | Hızlı İşlemler'den başlatın. |
| Safari ve macOS ağ ayarlarını kullanan uygulamalar | Parametreyi yok sayar; **Sistem Proxy**'yi açın. |
| Roblox | Parametreyi ve sistem proxy'sini yok sayar, `HTTPS_PROXY`'yi okur. Hızlı İşlemler'e ekleyip her zaman oradan başlatın; şifreyle giriş yaparken güvenlik doğrulaması için **Sistem Proxy**'yi de açın (bkz. [Roblox](#roblox)). Olmazsa **WireGuard/WARP**. |
| Oyunlar ve kendi ağ yığınını kullanan diğer uygulamalar | Parametreyi yok sayar, genellikle sistem proxy ayarını da kullanmaz; **WireGuard/WARP** kullanın. |
| Firefox | Kendi ayarı vardır: Ayarlar > Genel > Ağ Ayarları > Elle proxy yapılandırması: SOCKS sunucusu `127.0.0.1`, port `1080`, SOCKS v5; "SOCKS v5 kullanırken DNS'i proxy üzerinden yap" işaretli. |

### Sistem Proxy

**Hızlı İşlemler > Sistem Proxy > Aç**, birincil ağ servisinde (ör. Wi-Fi) hem **SOCKS proxy**'yi hem de **güvenli web proxy'sini (HTTPS)** `127.0.0.1:1080` olarak tek parola penceresiyle açar. Düz web proxy'si (HTTP) ve "proxy ayarlarını şu bilgisayarlar ve alan adları için atla" listesi değiştirilmez.

Safari gibi macOS proxy ayarlarını kullanan uygulamalar içindir. Roblox'un kendisi bu ayarı kullanmaz (onu Hızlı İşlemler'den başlatın), ama şifreyle girişteki güvenlik doğrulaması kullanır: giriş yaparken açın, sonra kapatabilirsiniz (bkz. [Roblox](#roblox)). Discord 0.0.419 ve sonrası bu ayarı da okur: ByeDPI çalışırken Sistem Proxy açıksa Dock'tan veya oturum açılışında başlayan Discord da ByeDPI'dan geçer.

- "Bizim proxy" sayılan durum: herhangi bir serviste SOCKS **veya** HTTPS proxy açık ve `127.0.0.1:1080`'i gösteriyor. Kapatırken yalnızca bizi gösteren ayarlar kapatılır; başka bir sunucuya ayarlı kendi proxy'nize dokunulmaz.
- v1.1.0'da açtığınız (yalnızca SOCKS) ayar da algılanır ve aynı şekilde otomatik kapatılır. HTTPS proxy'yi de eklemek için ByeDPI çalışırken **Aç**'a yeniden basın (veya kapatıp açın); başka ağ servislerinde kalmış yarım ayarlar da aynı parola penceresinde tamamlanır.
- Birincil serviste başka bir sunucuyu gösteren kendi SOCKS veya HTTPS proxy'niz (ör. şirket proxy'si) açıksa **Aç** onun üzerine yazmaz ve nedenini söyler; sistem proxy'yi kullanmak için önce o proxy'yi Sistem Ayarları'ndan kapatın.

- Yalnızca ByeDPI çalışırken açılabilir ve yalnızca ByeDPI çalışırken güvenlidir. Parola penceresi açıkken ByeDPI durursa proxy açılmaz.
- ByeDPI'ı **Durdur**duğunuzda, **Tümünü Zorla Kapat** kullandığınızda veya uygulamadan **çıktığınızda** otomatik kapatılır (yönetici parolası istenir; pencere nedenini yazar).
- ByeDPI beklenmedik şekilde durursa uygulama sizi uyarır ve proxy'yi kapatmayı önerir. Açılışta proxy açık ama ByeDPI çalışmıyorsa yine uyarır.
- ByeDPI'ı durdururken parola penceresini iptal ederseniz proxy açık kalır, internet çalışmaz ve uygulama uyarı gösterir: **Sistem Proxy > Kapat** ile kapatın veya ByeDPI'ı yeniden başlatın.
- Çıkışta proxy kapatılamazsa (parola iptal edildi veya hata) uygulama sorar: **Tekrar Dene**, **ByeDPI çalışsın, çık** (ByeDPI arka planda çalışmaya devam eder, internet çalışır) veya **Çıkma**. Oturum kapatma, yeniden başlatma ve bilgisayarı kapatmada soru sorulmaz; proxy açık kalmışsa SplitWire sonraki açılışta uyarır.
- Elle kapatma adımları [Sorun giderme](#sorun-giderme) bölümünde.

### Roblox

Ölçümlere göre Roblox'un web/giriş adresleri (ör. `www.roblox.com`, `clientsettings.roblox.com`, `gamejoin.roblox.com`) Discord ile aynı şekilde engelleniyor: DNS engelleme adresi döndürüyor ve doğru adresle bile doğrudan TLS bağlantısı DPI tarafından kesiliyor; ByeDPI üzerinden ise erişilebiliyor ([#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13)).

Roblox'un macOS istemcisi (libcurl) `--proxy-server` parametresini de macOS sistem proxy'sini de kullanmaz; v1.1.1'deki Sistem Proxy yolunun işe yaramamasının nedeni buydu. Ama `HTTPS_PROXY` ortam değişkenini okur ve Hızlı İşlemler bunu verir. `HTTPS_PROXY` ile başlatılan Roblox'un tüm HTTPS trafiği (`apis`, `auth`, `clientsettings(cdn)`, `gamejoin`, `ecsv2`, `realtime-signalr` vb. `roblox.com` adresleri) ByeDPI'dan geçti. Proxy olmadan Roblox'un günlüklerinde `SslConnectFail` (TLS sırasında bağlantı sıfırlanıyor, yani SNI engeli; ör. `ecsv2.roblox.com`) ve `TlsVerificationFail` (adres engelleme adresine çözülmüş) hataları görünür ve giriş yapılamaz.

Şifreyle girişte `auth.roblox.com` "Challenge is required" yanıtı verir ve Roblox bir güvenlik doğrulaması ("Security" ekranı) gösterir. Bu ekran `https://www.roblox.com/challenge/cdn/hybrid` sayfasını macOS'un web görünümünde açar ve bu görünüm `HTTPS_PROXY`'yi değil yalnızca macOS sistem proxy'sini kullanır. `www.roblox.com` engelli olduğu için (TLS sırasında bağlantı sıfırlanıyor) Sistem Proxy kapalıyken sayfa yüklenmez, "Security" ekranı boş kalır ve giriş ilerlemez. Sistem HTTPS proxy'si ByeDPI'ı gösterirken doğrulama açıldı ve giriş tamamlandı. Doğrulama sağlayıcıları (Arkose Labs, hCaptcha) engelli değil.

1. Önce DNS'i düzeltin: **Ağ Ayarları**'ndan 1.1.1.1 veya şifreli DNS (DoH) profili (uyarı Roblox için de görünür).
2. Roblox'u Hızlı İşlemler'e ekleyin ve her zaman oradan başlatın. Roblox kuruluysa ve Hızlı İşlemler'de yoksa ByeDPI sekmesinde **Roblox'u Hızlı İşlemler'e Ekle** düğmesi görünür (ya da **+** ile `/Applications/Roblox.app` seçin); düğme Roblox'u `--proxy-server` parametresi olmadan ekler, çünkü Roblox bu parametreyi kullanmaz ve `HTTPS_PROXY` yeterlidir. Roblox açıksa SplitWire onu (menü çubuğundaki Roblox simgesiyle birlikte) kapatıp yeniden açar.
3. Şifreyle giriş yaparken **Sistem Proxy**'yi de açın (**Hızlı İşlemler > Sistem Proxy > Aç**). Giriş yaptıktan sonra kapatabilirsiniz; "Security" ekranı yine boş kalırsa tekrar açın.
4. Oyunlara Roblox uygulamasının içinden girin. Roblox'u menü çubuğundan tamamen kapattıysanız tarayıcıdaki **Oyna** düğmesi onu proxy'siz açar; o zaman Roblox'u kapatıp Hızlı İşlemler'den yeniden açın.

Sistem Proxy kapalıyken Roblox'u Hızlı İşlemler'den başlatırsanız (DNS uyarısı yoksa) durum mesajı bunu hatırlatır: "Roblox ByeDPI proxy ile başlatıldı. Şifreyle giriş yapacaksanız güvenlik doğrulaması için Sistem Proxy'yi de açın."

Menü çubuğundaki Roblox simgesi ayrı bir uygulamadır (`Roblox.app` içindeki `RobloxMenuBar.app`). Roblox ile bu uygulama birbirini yaklaşık bir saniye içinde yeniden açar: kapatılan Roblox tepsi modunda (`-launchToTray`) geri gelir ve yeni açılan örnek ortam değişkenlerini onu açan süreçten alır. Menü çubuğu uygulaması açık değilken Roblox'tan çıkmak yalnızca penceresini kapatır; Roblox arka planda çalışmaya devam eder. Bu yüzden Roblox'u Hızlı İşlemler'den başlattığınızda SplitWire:

- menü çubuğu uygulamasını da kapatır (yalnızca o açıksa sormadan),
- geri gelen örneklere kapatma isteğini yeniden gönderir,
- Roblox 3 saniye içinde kapanmazsa "zorla kapatılsın mı?" diye sormadan zorla kapatır (**Kapat ve Yeniden Başlat**'ı zaten onayladınız; oyun ilerlemesi sunucuda tutulur),
- sonra Roblox'u `HTTPS_PROXY` ile açar; bu Roblox'un açtığı menü çubuğu uygulaması da değişkeni alır.

Denemede başka bir proxy ayarıyla açılmış Roblox ve menü çubuğu uygulaması 2,9 saniyede, penceresi kapatılıp arka planda kalmış bir Roblox 5,3 saniyede yenisiyle değiştirildi. Roblox'un kendini yeniden başlatmasını SplitWire göremez (Roblox'un `Info.plist`'inde `LSUIElement=true` olduğu için macOS onun açıldığını bildirmez); Discord'daki gibi otomatik yeniden açma Roblox için yoktur.

- Giriş yaptıktan sonra ByeDPI üzerinden oyuna katılma çalıştı (`gamejoin.roblox.com`, "Game join succeeded"). Oyun trafiği (UDP) proxy'den geçmez, doğrudan Roblox'un oyun sunucularına gider; bu yüzden proxy ping eklemez. Yeniden katılınca farklı bir sunucuya (farklı job id ve sunucu IP'si) bağlandı, yani sunucu değiştirmek çalışıyor. (WARP/WireGuard ile [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13)'teki bir kullanıcı yalnızca tek bir sunucuya girebildi ve ping'i yüksekti.)
- Bağlantı testindeki **Roblox** satırı, Roblox'un ayar sunucusuna (`clientsettings.roblox.com`) ByeDPI üzerinden ulaşılıp ulaşılamadığını gösterir.
- **Doğrulandı:** Yukarıdakiler 28 Ekim 2026'da Roblox 0.745.0.7451137 kurulu bir Mac'te (macOS 27) bir Türk operatöründe denendi. Ölçüm tek Mac'te ve tek operatörde yapıldı; başka operatörlerde farklı olabilir. Ping değerleri ölçülmedi. İşe yarasa da yaramasa da lütfen [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13) üzerinden bildirin.
- İşe yaramazsa **WireGuard/WARP** kullanın; tüm trafik tünelden geçtiği için ping daha yüksek olabilir.

### WireGuard / Cloudflare WARP modu

ByeDPI ile çalışmayan uygulamalar (oyunlar vb.) için alternatif. Tüm trafik WARP'tan geçtiği için çevrim içi oyunlarda ping artar ve bazı oyunlarda sunucu değiştirme sorunları yaşanabilir; Roblox için önce yukarıdaki yolu deneyin.

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

**Discord "Checking for updates…" ekranında kalıyor veya "update failed" diyor**
Discord açılışta güncelleme denetimi yapar ve bu denetim başarılı olmadan açılmaz. Denetim `--proxy-server` parametresini kullanmaz; 0.0.419'dan önceki sürümleri macOS sistem proxy'sini de okumaz; hepsi `HTTPS_PROXY`'yi okur. Denetim en çok TLS 1.2 kullanır ([#15](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/15)). Sırayla:
1. DNS: Üstte DNS uyarısı varsa önce onu düzeltin (aşağıdaki DNS zehirlenmesi maddesi).
2. Bağlantı testi: **ByeDPI Durumu** bölümünde **Test Et** / **Tekrar Test Et**. Yalnızca "Discord güncelleme denetimi (TLS 1.2)" başarısızsa seçili yöntem TLS 1.2'yi geçirmiyordur: **Split 2 (önerilen)**'yi seçin. Zaten Split 2'deyseniz Özel yöntemde ör. `-s 3 --tlsrec 1+s` deneyin.
3. Discord'u Hızlı İşlemler'den **yeniden başlatın**. Dock'tan, Spotlight'tan veya v1.1.1 ve öncesiyle başlatılmış Discord'a `HTTPS_PROXY` verilmemiştir.
4. Çalışan ByeDPI uygulama dışında (ör. eski bir sürümle) `-G` olmadan başlatılmışsa güncelleme denetimi geçemez ve SplitWire bunu söyler: ByeDPI'ı durdurup yeniden başlatın.
5. Hâlâ olmuyorsa **Gelişmiş > Discord Günlüklerini Aç** ile Discord'un günlük klasörünü açın ve günlükleri issue'ya ekleyin.
- Eski rehberlerdeki `SKIP_HOST_UPDATE` / `SKIP_MODULE_UPDATE` ayarları güncel macOS Discord'da etkisizdir; gerek yoktur.

**Roblox açılmıyor veya bağlanmıyor**
1. DNS uyarısı varsa önce onu düzeltin.
2. Roblox'u Hızlı İşlemler'den başlattığınızdan emin olun. Dock'tan, Launchpad'den veya tarayıcıdaki **Oyna** ile açılan Roblox proxy kullanmaz. Roblox'un kendisi Sistem Proxy'yi kullanmaz; bu yüzden Sistem Proxy, Roblox'u Hızlı İşlemler'den başlatmanın yerini tutmaz.
3. Şifreyle girişte "Security" ekranı boş kalıyorsa **Sistem Proxy**'yi açın: güvenlik doğrulaması macOS'un web görünümünde açılır ve yalnızca sistem proxy'sini kullanır. Giriş yaptıktan sonra kapatabilirsiniz; ekran yine boş kalırsa tekrar açın.
4. Bağlantı testinde **Roblox** başarısızsa başka bir yöntem deneyin.
5. Olmazsa **WireGuard/WARP** kullanın ve sonucu [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13) üzerinden bildirin.

**Discord / Roblox açılmıyor (DNS zehirlenmesi)**
Bazı operatörlerin DNS sunucuları `discord.com` ve `www.roblox.com` için gerçek adres yerine engelleme sayfası adresi (`195.175.254.2`) döndürür. ciadpi hedef adresleri (SOCKS ve HTTPS proxy) sistem DNS'i ile çözdüğü için DPI aşılsa bile bağlantı engelleme sayfasına gider; bağlantı testinde de hiçbir satır geçmez. Çözüm:
1. DNS'i Cloudflare (1.1.1.1) yapın (uyarıdaki düğme veya **Ağ Ayarları** sekmesi).
2. Uyarı sürüyorsa operatörünüz 53. port DNS trafiğini yakalıyordur: DoH profilini yükleyin ya da WireGuard/WARP kullanın.
3. Discord'u ve Roblox'u Hızlı İşlemler'den **yeniden başlatın**.

Test için (ByeDPI çalışırken):
```bash
curl -I --socks5-hostname 127.0.0.1:1080 https://discord.com
curl -I --proxy http://127.0.0.1:1080 https://www.roblox.com                  # HTTPS proxy (HTTP CONNECT)
curl -I --tls-max 1.2 --proxy http://127.0.0.1:1080 https://updates.discord.com # TLS 1.2 (Discord güncelleme denetimi gibi)
```

**"Port 1080 kullanımda"**
- Önceki oturumdan kalmış bir ciadpi varsa uygulama **Süreçleri Kapat ve Tekrar Dene** seçeneğini sunar.
- Başka bir program kullanıyorsa hata mesajı programın adını ve PID'sini gösterir; o programı kapatın.
- Menü çubuğu veya Hızlı İşlemler > **Tümünü Zorla Kapat** tüm ciadpi süreçlerini sonlandırır.
- Elle: `lsof -nP -iTCP:1080 -sTCP:LISTEN` ile kontrol edin, `pkill -9 -x ciadpi` ile kapatın (ciadpi normal `kill` sinyalini yok sayar).

**Proxy açık kaldı, internet çalışmıyor**
1. Önce SplitWire'ı açın: Açılışta durumu algılar ve **Sistem Proxy'yi Kapat** seçeneği sunar.
2. Elle: **Sistem Ayarları > Ağ >** (Wi-Fi veya Ethernet) **> Ayrıntılar… > Proxy'ler** > **SOCKS proxy** ve **Güvenli web proxy'si (HTTPS)** seçeneklerini kapatın > **Tamam**.
3. Terminal ile: `networksetup -listallnetworkservices` ile servis adını bulun, sonra:
   ```bash
   sudo networksetup -setsocksfirewallproxystate "Wi-Fi" off
   sudo networksetup -setsecurewebproxystate "Wi-Fi" off
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

./build.sh                     # evrensel sürüm: SplitWire-Turkey.app + dist/SplitWire-Turkey-v1.1.3.zip (+ .sha256)
./build.sh --arch-native       # hızlı geliştirme derlemesi (yalnızca bu Mac'in mimarisi, zip yok)
./build.sh 1.1.3 --skip-zip    # .app'i derle, imzala ve doğrula; zip oluşturma
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

- **ByeDPI (ciadpi):** Runs a local proxy on `127.0.0.1:1080` that gets around your ISP's DPI (deep packet inspection) blocking. The same port accepts both SOCKS5 and HTTPS (HTTP CONNECT) connections. The proxy is reachable from this Mac only, not from other devices on your network.
- **Quick actions:** Launches Discord, Roblox and other apps through ByeDPI with one click: Chromium/Electron apps get the `--proxy-server` flag, and programs that read `HTTPS_PROXY`, such as Discord's update check and Roblox, get the environment variable. If the app is already running, it offers to quit and relaunch it. If an app opened from here restarts itself without the proxy (e.g. Discord after an update), SplitWire reopens it with ByeDPI (not Roblox: macOS doesn't report its launch; see [Roblox](#roblox-1)).
- **Connection test:** When ByeDPI starts and when the method changes, it tries to reach Discord, Discord's update check (TLS 1.2) and Roblox through ByeDPI. The result shows in the **ByeDPI status** section and says whether the problem is DNS or the method.
- **DNS blocking check:** At launch, checks whether Discord (`discord.com`, `gateway.discord.gg`) resolves to its real addresses or to a block page by comparing with encrypted DNS; for Roblox (`www.roblox.com`) it checks the known block addresses and the address Discord was found poisoned with. It tells you which services are affected. Offers one-click Cloudflare DNS (1.1.1.1) and an encrypted DNS (DoH) profile.
- **System proxy (optional):** System-wide SOCKS and HTTPS proxy settings for apps that use the macOS proxy settings (e.g. Safari). Roblox itself doesn't use them, but its security check when signing in with a password does. They are turned off automatically when ByeDPI stops or you quit the app.
- **WireGuard / Cloudflare WARP:** A tunnel that sends all traffic through Cloudflare WARP (requires Homebrew `wireguard-tools`).
- **Menu bar:** Start/stop, DPI method selection, system proxy status. The Dock icon can be hidden; the interface is available in Turkish and English.

### Requirements

- macOS 13 Ventura or later
- Apple Silicon **or** Intel Mac (the app and ciadpi are universal binaries)
- Your administrator password for actions that change system settings (DNS, system proxy, WireGuard). ByeDPI itself does not need admin rights.
- WireGuard mode only: [Homebrew](https://brew.sh) and `brew install wireguard-tools`

### Installation

1. Download `SplitWire-Turkey-v1.1.3.zip` from [Releases](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/releases) and unzip it.
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
   - SplitWire launches Discord with the `--proxy-server` flag and the `HTTPS_PROXY` environment variable. Both are needed: Discord checks for updates at startup and stays on "Checking for updates…" until that check succeeds. The check doesn't use `--proxy-server`; versions before 0.0.419 don't read the macOS system proxy either; all of them read `HTTPS_PROXY` ([#15](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/15)).
   - If Discord is already running, the app offers **Quit and relaunch**. The proxy setting only applies to a Discord instance started this way.
   - If you open Discord from the Dock or Spotlight, it doesn't get the proxy flag or `HTTPS_PROXY`; always launch it from SplitWire. (With Discord 0.0.419 and later, if [System proxy](#system-proxy) is on while ByeDPI runs, Discord opened from the Dock goes through ByeDPI too.)
   - If Discord installs an update and restarts itself without the proxy, SplitWire detects this and reopens Discord with ByeDPI (at most 3 times in 10 minutes).
4. Look at the connection test in the **ByeDPI status** section: it says whether the problem is DNS or the method. If needed, choose another DPI method (see below). If ByeDPI is running, it restarts with the new method automatically; if the new method fails to start, it goes back to the previous one.

### DPI methods (presets)

Your choice is saved, and the main window and menu bar always show the same method. The active method and the exact ciadpi arguments are shown under **ByeDPI status**.

| Method | ciadpi arguments |
|---|---|
| Standard (stored as "Standart") | `-r 1+s` |
| Split 1 | `-s 1 --tlsrec 1+s` |
| Split 2 (recommended, default) | `-s 2 --tlsrec 1+s` |
| Disorder | `--disorder 1 --auto=torst --tlsrec 1+s` |
| Disorder SNI | `-d 1+s --tlsrec 1+s` |
| OOB | `-o 1 --auto=torst` |
| OOB SNI | `-o 1+s --tlsrec 1+s` |
| Split + Disorder | `-s 1+s -d 3+s --tlsrec 1+s` |
| Custom | Your own arguments |

- `-i 127.0.0.1 -p 1080 -G` is added automatically (unless your Custom arguments set `-i`/`-p`/`-G`). `-G` (`--http-connect`) makes the same port accept HTTP CONNECT requests next to SOCKS5; the system HTTPS proxy and the `HTTPS_PROXY` variable set by Quick actions use it. ciadpi can't serve plain HTTP proxy requests (`GET http://…`), so the plain web proxy (HTTP) is never set.
- **Why Split 2:** Discord's update check uses TLS 1.2 at most. In TLS 1.2 the server certificate is sent unencrypted, so the ISP's DPI can recognize the connection by its certificate and cut it. In a measurement on a Turkish ISP on 28 October 2026, every built-in method except Split 2 got TLS 1.3 through, but TLS 1.2 connections were reset after the server's first 1400 bytes. Split 2 (and any `-s N` with N≥2) got both through on `discord.com`, `updates.discord.com`, `gateway.discord.gg`, `cdn.discordapp.com`, `discordapp.com`, `www.roblox.com`, `clientsettings.roblox.com`, `apis.roblox.com` and `auth.roblox.com`. The measurement comes from a single ISP; if "Discord update check" fails in the connection test, try other methods and please report the result.
- **Standard is no longer the default:** you can still choose it, but in the measurement it only got TLS 1.3 through. When you upgrade from v1.1.1 with Standard selected, you are switched to Split 2 once and the app says so in the status message; if you choose Standard again, it isn't changed again.
- **Fake presets were removed:** ciadpi built for macOS can't send fake packets (`FAKE_SUPPORT` is Linux/Windows only). If you had a Fake preset or an unknown method selected, it falls back to Split 2.
- Try Split 2 first. Most of the time the real problem is DNS: fix the DNS warning first, then look at the connection test.

### Which apps honor the proxy setting?

Quick actions launch the app with `--proxy-server=socks5://127.0.0.1:1080` (editable per app) and the `HTTPS_PROXY=http://127.0.0.1:1080` environment variable (plus `https_proxy`, and `NO_PROXY` / `no_proxy` = `localhost,127.0.0.1,::1`). `HTTP_PROXY` and `ALL_PROXY` are deliberately not set: ciadpi isn't a plain HTTP proxy, so unencrypted HTTP requests would break. The environment variables are inherited by the app's child processes too; when you stop ByeDPI, quit those apps and open them normally.

| App type | What to do |
|---|---|
| Discord | Launch it from Quick actions. Its windows use the proxy flag and its startup update check uses `HTTPS_PROXY`; both are set ([#15](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/15)). |
| Other Chromium/Electron based apps (Chrome, Brave, Edge, Slack, Spotify…) | Launch it from Quick actions. |
| Safari and apps that use macOS network settings | Ignore the flag; turn on **System proxy**. |
| Roblox | Ignores the flag and the system proxy, reads `HTTPS_PROXY`. Add it to Quick actions and always start it from there; while signing in with a password, also turn on **System proxy** for the security check (see [Roblox](#roblox-1)). Otherwise use **WireGuard/WARP**. |
| Games and other apps with their own network stack | Ignore the flag and usually the system proxy settings too; use **WireGuard/WARP**. |
| Firefox | Has its own setting: Settings > General > Network Settings > Manual proxy configuration: SOCKS host `127.0.0.1`, port `1080`, SOCKS v5, with "Proxy DNS when using SOCKS v5" checked. |

### System proxy

**Quick actions > System proxy > Turn on** sets both the **SOCKS proxy** and the **secure web proxy (HTTPS)** of your primary network service (e.g. Wi-Fi) to `127.0.0.1:1080`, with a single password prompt. The plain web proxy (HTTP) and the "bypass proxy settings for these hosts & domains" list are not changed.

It is meant for apps that use the macOS proxy settings, such as Safari. Roblox itself doesn't use it (start Roblox from Quick actions), but the security check when signing in with a password does: turn it on while signing in; you can turn it off afterwards (see [Roblox](#roblox-1)). Discord 0.0.419 and later read this setting too: while ByeDPI runs with System proxy on, Discord opened from the Dock or at login also goes through ByeDPI.

- "Our proxy" means: on any service, the SOCKS **or** HTTPS proxy is on and points to `127.0.0.1:1080`. Turning it off only switches off the settings that point to us; your own proxy pointing to another server is left alone.
- A SOCKS-only setting turned on with v1.1.0 is detected too and is turned off automatically in the same way. To add the HTTPS proxy as well, press **Turn on** again while ByeDPI is running (or turn it off and on); partial settings left on other network services are completed in the same password prompt.
- If your own SOCKS or HTTPS proxy pointing to another server (e.g. a company proxy) is on for the primary service, **Turn on** won't overwrite it and tells you why; to use the system proxy, turn that proxy off in System Settings first.

- It can only be turned on while ByeDPI is running, and it is only safe while ByeDPI is running. If ByeDPI stops while the password prompt is open, the proxy is not turned on.
- It is turned off automatically when you **Stop** ByeDPI, use **Force stop all**, or **quit** the app (your administrator password is required; the prompt says why).
- If ByeDPI stops unexpectedly, the app warns you and offers to turn the proxy off. At launch, it also warns you if the proxy is on but ByeDPI isn't running.
- If you cancel the password prompt while stopping ByeDPI, the proxy stays on, your internet won't work, and the app shows a warning: turn it off with **System proxy > Turn off** or start ByeDPI again.
- If the proxy can't be turned off when you quit (password cancelled or an error), the app asks: **Try again**, **Quit, keep ByeDPI running** (ByeDPI keeps running in the background, so your internet keeps working) or **Don't quit**. There is no prompt on log out, restart or shut down; if the proxy was left on, SplitWire warns you the next time it opens.
- To turn it off manually, see [Troubleshooting](#troubleshooting).

### Roblox

Measurements show Roblox's web/login hosts (e.g. `www.roblox.com`, `clientsettings.roblox.com`, `gamejoin.roblox.com`) are blocked the same way as Discord: DNS returns the block address, and even with the correct address a direct TLS connection is cut by DPI; through ByeDPI they are reachable ([#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13)).

Roblox's macOS client (libcurl) uses neither the `--proxy-server` flag nor the macOS system proxy, which is why the System proxy route in v1.1.1 didn't work. It does read the `HTTPS_PROXY` environment variable, and Quick actions set it. Launched with `HTTPS_PROXY`, all of Roblox's HTTPS traffic (`apis`, `auth`, `clientsettings(cdn)`, `gamejoin`, `ecsv2`, `realtime-signalr` and other `roblox.com` hosts) went through ByeDPI. Without the proxy, Roblox's logs show `SslConnectFail` (the connection is reset during TLS, i.e. SNI blocking; e.g. `ecsv2.roblox.com`) and `TlsVerificationFail` (the host resolved to the block address), and sign-in fails.

When you sign in with a password, `auth.roblox.com` answers "Challenge is required" and Roblox shows a security check (the "Security" screen). That screen loads `https://www.roblox.com/challenge/cdn/hybrid` in a macOS web view, and that web view uses only the macOS system proxy, not `HTTPS_PROXY`. Because `www.roblox.com` is blocked (the connection is reset during TLS), the page never loads while System proxy is off: the "Security" screen stays blank and sign-in is stuck. With the system HTTPS proxy pointing at ByeDPI, the check loaded and sign-in completed. The captcha providers (Arkose Labs, hCaptcha) are not blocked.

1. Fix DNS first: 1.1.1.1 or the encrypted DNS (DoH) profile in the **Network** tab (the banner covers Roblox too).
2. Add Roblox to Quick actions and always start it from there. If Roblox is installed and not yet in Quick actions, the ByeDPI tab shows an **Add Roblox to Quick actions** button (or click **+** and choose `/Applications/Roblox.app`); the button adds Roblox without the `--proxy-server` flag, because Roblox doesn't use it and `HTTPS_PROXY` is enough. If Roblox is open, SplitWire quits it (together with the Roblox menu bar icon) and reopens it.
3. Turn on **System proxy** while signing in with a password (**Quick actions > System proxy > Turn on**). You can turn it off after signing in; if the "Security" screen is blank again, turn it on again.
4. Join games from inside the Roblox app. If you fully quit Roblox from the menu bar, the **Play** button in the browser opens it without the proxy; then quit Roblox and reopen it from Quick actions.

If you start Roblox from Quick actions while System proxy is off (and there is no DNS warning), the status message reminds you: "Roblox was launched with the ByeDPI proxy. If you sign in with a password, also turn on System proxy for the security check."

The Roblox icon in the menu bar is a separate app (`RobloxMenuBar.app` inside `Roblox.app`). Roblox and this app restart each other within about a second: a quit Roblox comes back in tray mode (`-launchToTray`), and a new instance inherits the environment of whichever process launched it. If the menu bar app isn't running, quitting Roblox only closes its window and Roblox keeps running in the background. So when you start Roblox from Quick actions, SplitWire:

- also quits the menu bar app (without asking when only the menu bar app is open),
- sends the quit request again to instances that come back,
- force-quits Roblox without the "force quit?" dialog if it hasn't quit within 3 seconds (you already confirmed **Quit and relaunch**; game progress is kept on the server),
- then opens Roblox with `HTTPS_PROXY`; a menu bar app started by that Roblox inherits it too.

In testing, a Roblox and menu bar app started with another proxy setting were replaced in 2.9 seconds, and a Roblox whose window was closed and that kept running in the background was replaced in 5.3 seconds. SplitWire can't see Roblox restarting itself (Roblox's `Info.plist` has `LSUIElement=true`, so macOS doesn't announce its launch); there is no automatic reopen for Roblox like the one for Discord.

- After signing in, joining a game through ByeDPI worked (`gamejoin.roblox.com`, "Game join succeeded"). Game traffic (UDP) doesn't go through the proxy but straight to Roblox's game servers, so the proxy doesn't add ping. Joining again landed on a different server (different job id and server IP), so switching servers works. (With WARP/WireGuard, a reporter on [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13) could only join one server and had high ping.)
- The **Roblox** line in the connection test shows whether Roblox's settings server (`clientsettings.roblox.com`) is reachable through ByeDPI.
- **Verified:** the above was tried on 28 October 2026 on a Mac (macOS 27) with Roblox 0.745.0.7451137 installed, on a Turkish ISP. It was measured on one Mac on one ISP; other ISPs may behave differently. Ping values were not measured. Please report on [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13) whether it works for you or not.
- If it doesn't work, use **WireGuard/WARP**; since all traffic goes through the tunnel, ping may be higher.

### WireGuard / Cloudflare WARP mode

An alternative for apps that don't work with ByeDPI (games, etc.). Because all traffic goes through WARP, online games get higher ping and some games may have trouble switching servers; for Roblox, try the route above first.

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

**Discord stays on "Checking for updates…" or says "update failed"**
Discord checks for updates at startup and doesn't open until that check succeeds. The check doesn't use the `--proxy-server` flag; versions before 0.0.419 don't read the macOS system proxy either; all of them read `HTTPS_PROXY`. The check uses TLS 1.2 at most ([#15](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/15)). In order:
1. DNS: if the DNS warning is shown, fix it first (see the DNS poisoning entry below).
2. Connection test: **Test** / **Test again** in the **ByeDPI status** section. If only "Discord update check (TLS 1.2)" fails, the selected method doesn't get TLS 1.2 through: choose **Split 2 (recommended)**. If you are already on Split 2, try e.g. `-s 3 --tlsrec 1+s` as a Custom method.
3. **Relaunch** Discord from Quick actions. A Discord opened from the Dock, from Spotlight or with v1.1.1 and earlier didn't get `HTTPS_PROXY`.
4. If the running ByeDPI was started outside the app (e.g. by an older version) without `-G`, the update check can't get through and SplitWire says so: stop and restart ByeDPI.
5. Still stuck? Use **Advanced > Open Discord logs** to open Discord's log folder and attach the logs to an issue.
- The `SKIP_HOST_UPDATE` / `SKIP_MODULE_UPDATE` settings from older guides have no effect on current macOS Discord; you don't need them.

**Roblox doesn't open or connect**
1. If the DNS warning is shown, fix it first.
2. Make sure you start Roblox from Quick actions. Roblox opened from the Dock, Launchpad or the browser's **Play** button doesn't use the proxy. Roblox itself doesn't use System proxy, so System proxy doesn't replace starting Roblox from Quick actions.
3. If the "Security" screen stays blank while signing in with a password, turn on **System proxy**: the security check opens in a macOS web view, which only uses the system proxy. You can turn it off after signing in; if the screen is blank again, turn it on again.
4. If **Roblox** fails in the connection test, try another method.
5. Otherwise use **WireGuard/WARP**, and please report the result on [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13).

**Discord / Roblox doesn't load (DNS poisoning)**
Some ISPs' DNS servers return a block-page address (`195.175.254.2`) instead of the real address for `discord.com` and `www.roblox.com`. ciadpi resolves target hosts (SOCKS and HTTPS proxy) with the system DNS, so even with DPI bypassed the connection goes to the block page, and no line passes in the connection test. Fix:
1. Set DNS to Cloudflare (1.1.1.1) (button in the banner, or the **Network** tab).
2. If the warning persists, your ISP intercepts DNS on port 53: install the DoH profile or use WireGuard/WARP.
3. **Relaunch** Discord and Roblox from Quick actions.

To test (while ByeDPI is running):
```bash
curl -I --socks5-hostname 127.0.0.1:1080 https://discord.com
curl -I --proxy http://127.0.0.1:1080 https://www.roblox.com                  # HTTPS proxy (HTTP CONNECT)
curl -I --tls-max 1.2 --proxy http://127.0.0.1:1080 https://updates.discord.com # TLS 1.2 (like Discord's update check)
```

**"Port 1080 is in use"**
- If a ciadpi from a previous session is still running, the app offers **Stop processes and retry**.
- If another program uses the port, the error shows its name and PID; quit that program.
- Menu bar or Quick actions > **Force stop all** kills every ciadpi process.
- Manually: check with `lsof -nP -iTCP:1080 -sTCP:LISTEN` and stop it with `pkill -9 -x ciadpi` (ciadpi ignores a normal `kill`).

**The proxy stayed on and the internet doesn't work**
1. Open SplitWire first: at launch it detects this and offers **Turn off system proxy**.
2. Manually: **System Settings > Network >** (Wi-Fi or Ethernet) **> Details… > Proxies** > turn off **SOCKS proxy** and **Secure web proxy (HTTPS)** > **OK**.
3. In Terminal: find the service name with `networksetup -listallnetworkservices`, then:
   ```bash
   sudo networksetup -setsocksfirewallproxystate "Wi-Fi" off
   sudo networksetup -setsecurewebproxystate "Wi-Fi" off
   ```

**WireGuard setup fails**
- "wgcf: line 1: Not: command not found": the broken file downloaded by v1.0.0. v1.1.0 detects it and downloads wgcf again during setup.
- "WireGuard tools required": run `brew install wireguard-tools`, then try again.
- Setup and connection errors are shown in the WireGuard tab. Start-at-boot log (only if that option is on): `/var/log/splitwire-wireguard.log`

More (in Turkish): [KULLANIM.md](KULLANIM.md).

### Build from source

Requirements: macOS and full **Xcode** 15+ (Swift 5.9+). The Command Line Tools alone are not enough: in newer SDKs (e.g. the macOS 27 SDK) SwiftUI's `@State` is a macro, and the Command Line Tools don't ship the `SwiftUIMacros` plugin (`libSwiftUIMacros`). `build.sh` detects this before building and stops. If you can't install Xcode, build against an older SDK: `SDKROOT=$(xcrun --sdk macosx26.5 --show-sdk-path) ./build.sh` (see `./build.sh --help`).

```bash
git clone https://github.com/a-mertdincer/SplitWire-Turkey-macOS.git
cd SplitWire-Turkey-macOS

./build.sh                     # universal release: SplitWire-Turkey.app + dist/SplitWire-Turkey-v1.1.3.zip (+ .sha256)
./build.sh --arch-native       # fast dev build (this Mac's architecture only, no zip)
./build.sh 1.1.3 --skip-zip    # build, sign and verify the .app without the zip
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
