# SplitWire-Turkey macOS - Kullanım Kılavuzu

Bu kılavuz v1.1.2 içindir. Kısa özet ve İngilizce açıklama için [README.md](README.md), sürüm notları için [RELEASE_NOTES_v1.1.2.md](RELEASE_NOTES_v1.1.2.md), [RELEASE_NOTES_v1.1.1.md](RELEASE_NOTES_v1.1.1.md) ve [RELEASE_NOTES_v1.1.0.md](RELEASE_NOTES_v1.1.0.md) dosyalarına bakın.

İçindekiler:

1. [Kurulum](#kurulum)
2. [Arayüz](#arayüz)
3. [Discord için hızlı başlangıç](#discord-için-hızlı-başlangıç)
4. [ByeDPI](#byedpi)
5. [Roblox](#roblox)
6. [Sistem Proxy](#sistem-proxy)
7. [DNS ayarları](#dns-ayarları)
8. [Şifreli DNS (DoH) profili](#şifreli-dns-doh-profili)
9. [WireGuard / Cloudflare WARP](#wireguard--cloudflare-warp)
10. [Dock simgesi, dil ve koyu mod](#dock-simgesi-dil-ve-koyu-mod)
11. [Sorun giderme](#sorun-giderme)
12. [Güncelleme (v1.1.1, v1.1.0 ve v1.0.0'dan)](#güncelleme)
13. [Tamamen kaldırma](#tamamen-kaldırma)

---

## Kurulum

Gereksinimler: macOS 13 veya üstü, Apple Silicon veya Intel Mac.

1. [Releases](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/releases) sayfasından `SplitWire-Turkey-v1.1.2.zip` dosyasını indirin ve çift tıklayarak açın.
2. `SplitWire-Turkey.app` dosyasını **Uygulamalar** klasörüne sürükleyin.
3. Uygulamayı açın.

### Gatekeeper uyarısı (ilk açılış)

Uygulama ad-hoc imzalıdır; Apple Developer ID ile imzalanmamış ve notarize edilmemiştir. Bu yüzden macOS ilk açılışta uyarı verir:

- **macOS 13–14:** Uygulamalar klasöründe uygulamaya sağ tıklayın (Control-tık) > **Aç** > açılan pencerede tekrar **Aç**.
- **macOS 15 ve sonrası:** Uygulamayı bir kez açmayı deneyin ve uyarıyı kapatın. **Sistem Ayarları > Gizlilik ve Güvenlik** bölümünü açın, en altta SplitWire-Turkey için görünen **Yine de Aç** düğmesine basın ve parolanızı girin.
- **Terminal ile (tüm sürümler):**
  ```bash
  xattr -dr com.apple.quarantine /Applications/SplitWire-Turkey.app
  ```

İsteğe bağlı: Sürüm sayfasında `.sha256` dosyası da varsa, indirdiğiniz zip'i doğrulayabilirsiniz (iki dosya aynı klasördeyken):

```bash
shasum -a 256 -c SplitWire-Turkey-v1.1.2.zip.sha256
```

---

## Arayüz

**Pencerenin üst kısmı:** Dil seçici (Türkçe / English), **Dock simgesini gizle** onay kutusu ve koyu mod anahtarı.

**Sekmeler:**

| Sekme | İçerik |
|---|---|
| WireGuard | Cloudflare WARP tüneli: kurulum, açılışta otomatik bağlanma seçeneği, bağlan/bağlantıyı kes, kaldırma |
| ByeDPI (açılışta seçili) | DNS uyarısı, ByeDPI durumu ve bağlantı testi, Hızlı İşlemler, DPI yöntemleri, Roblox notu, Gelişmiş (Discord sorun giderme) |
| Ağ Ayarları | DNS durumu, DNS sunucusu seçimi, DNS önbelleği, şifreli DNS (DoH) profili |
| Hakkında | Sürüm (derleme numarası ve commit dahil), emeği geçenler, GitHub / Sorun Bildir / Sürümler bağlantıları |

**Menü çubuğu (kalkan simgesi):** ByeDPI çalışırken kalkan, durmuşken üstü çizili kalkan simgesi görünür. Menüde:

- ByeDPI durumu ve çalışan yöntem (fareyle üzerine gelince tam parametreler görünür)
- **ByeDPI'ı Başlat** / **ByeDPI'ı Durdur**, **Tümünü Zorla Kapat**
- ByeDPI çalışırken **SOCKS5: 127.0.0.1:1080 (Kopyala)**
- Sistem proxy açıksa durumu ve **Sistem Proxy'yi Kapat**
- **DPI Yöntemi** alt menüsü
- **Ana Pencereyi Göster**, **Dock simgesini gizle**, **Çıkış**

Pencereyi kapatmak uygulamayı kapatmaz; uygulama menü çubuğunda çalışmaya devam eder. Pencereyi geri getirmek için menü çubuğu > **Ana Pencereyi Göster** (veya uygulama öndeyken Pencere menüsü > ⌘0).

---

## Discord için hızlı başlangıç

1. **ByeDPI** sekmesinde **Başlat**'a basın.
2. Sekmenin en üstünde turuncu **"DNS engellemesi algılandı"** kutusu varsa:
   1. **DNS'i Cloudflare (1.1.1.1) Yap**'a basın ve yönetici parolanızı girin.
   2. Kutu birkaç saniye içinde kaybolmazsa **Şifreli DNS (DoH) Profili…** ile profili yükleyin ([adımlar](#şifreli-dns-doh-profili)).
   3. **Tekrar Kontrol Et** ile doğrulayın.
3. **Hızlı İşlemler** bölümündeki **Discord** simgesine tıklayın. Discord, `--proxy-server` parametresi ve `HTTPS_PROXY` ortam değişkeniyle açılır ([ayrıntılar](#proxy-parametresi-ve-https_proxy)).
   - Discord açıksa **Kapat ve Yeniden Başlat**'ı seçin. 8 saniye içinde kapanmazsa zorla kapatmak isteyip istemediğiniz sorulur.
   - Discord'u her seferinde buradan başlatın. Dock veya Spotlight'tan açılan Discord'a proxy parametresi ve `HTTPS_PROXY` verilmez; açılıştaki güncelleme denetimi geçemez ve Discord "Checking for updates…" ekranında kalabilir. (Discord 0.0.419 ve sonrası sistem proxy'sini de okur; ByeDPI çalışırken [Sistem Proxy](#sistem-proxy) açıksa Dock'tan açılan Discord da ByeDPI'dan geçer.)
   - Discord güncellemeyi kurup kendini yeniden başlatırsa SplitWire onu ByeDPI ile yeniden açar ([ayrıntılar](#kendini-yeniden-başlatan-uygulamalar)).
4. **ByeDPI Durumu** bölümündeki [bağlantı testinin](#bağlantı-testi) sonucuna bakın. "Discord güncelleme denetimi (TLS 1.2)" başarısızsa **Önceden Hazır Ayarlar** bölümünden **Split 2 (önerilen)**'yi seçin; zaten seçiliyse [DPI yöntemi seçme](#dpi-yöntemi-seçme) bölümündeki sırayla başka bir yöntem deneyin.

> İpucu: Discord "Checking for updates…" ekranında kalıyorsa veya "update failed" diyorsa [Sorun giderme](#sorun-giderme) bölümüne bakın. Eski rehberlerdeki `SKIP_HOST_UPDATE` / `SKIP_MODULE_UPDATE` ayarları güncel macOS Discord'da etkisizdir; gerek yoktur.

---

## ByeDPI

ByeDPI (ciadpi), bu Mac'te `127.0.0.1:1080` adresinde dinleyen yerel bir proxy'dir. Aynı port hem SOCKS5 hem HTTPS (HTTP CONNECT) bağlantılarını kabul eder. Yalnızca bu bilgisayardan erişilebilir. Yönetici yetkisi gerektirmez.

### Başlatma ve durdurma

- **Başlat / Durdur:** ByeDPI sekmesi > Hızlı İşlemler veya menü çubuğu.
- **Tümünü Zorla Kapat:** Kendi başlattığınız ya da önceki oturumdan kalmış tüm ciadpi süreçlerini sonlandırır. Gerekirse yönetici parolası ister ve açıksa sistem proxy'yi de aynı pencerede kapatır.
- ByeDPI beklenmedik şekilde durursa durum mesajında ciadpi'nin hata çıktısı görünür.
- Önceki bir oturumdan kalmış bir ciadpi çalışıyorsa durum **Çalışıyor (harici süreç)** olarak görünür. Seçili yöntemi uygulamak için durdurup yeniden başlatın.
- v1.0.0'dan kalma bir ciadpi tüm ağ arayüzlerinde dinliyorsa (aynı ağdaki herkes proxy'yi kullanabilir) ByeDPI sekmesinde kırmızı, menü çubuğunda turuncu uyarı görünür ve uygulama **Güvenli Yeniden Başlat** ile yalnızca `127.0.0.1`'de yeniden başlatmayı önerir. Süreç başka bir kullanıcıya aitse **Tümünü Zorla Kapat**'ı kullanın.

### Bağlantı testi

ByeDPI başlayınca ve yöntem değişince SplitWire, ByeDPI'ın HTTPS proxy'si (HTTP CONNECT) üzerinden üç adrese bağlanmayı dener. Discord'un güncelleme denetimi ve Roblox da bu yoldan geçer. Testi **ByeDPI Durumu** bölümündeki **Test Et** / **Tekrar Test Et** düğmesiyle elle de çalıştırabilirsiniz.

| Satır | Adres |
|---|---|
| Discord (uygulama) | `https://discord.com/api/v9/gateway` |
| Discord güncelleme denetimi (TLS 1.2) | `https://updates.discord.com/distributions/app/manifests/latest?…` (TLS en çok 1.2, Discord'un güncelleyicisi gibi) |
| Roblox | `https://clientsettings.roblox.com/v2/client-version/MacPlayer` |

Sunucu herhangi bir HTTP yanıtı verirse satır başarılı sayılır. Başarısız satırın üzerine fareyle gelince hata nedeni görünür. Satırların altında bir teşhis yazar:

| Sonuç | Teşhis |
|---|---|
| Hepsi geçti | ByeDPI üzerinden Discord (güncelleme denetimi dahil) ve Roblox'a ulaşılabiliyor. |
| Yalnızca Discord güncelleme denetimi başarısız | Yöntem TLS 1.2'yi geçirmiyor; Discord "Checking for updates…" ekranında kalır. **Split 2 (önerilen)**'yi seçin. Zaten Split 2'deyseniz Özel yöntemde ör. `-s 3 --tlsrec 1+s` deneyin. |
| Hiçbiri geçmedi, DNS engeli algılanmış | ciadpi engelleme adresine bağlanıyor: önce DNS'i düzeltin ([DNS ayarları](#dns-ayarları)). |
| Hiçbiri geçmedi | Başka bir yöntem deneyin; DNS'i de kontrol edin. |
| Bazıları başarısız | Ulaşılamayanlar yazılır; başka bir yöntem deneyin. |

Sonuçlar yalnızca o an çalışan yönteme aittir: yöntem değişince veya ByeDPI durunca silinir.

### DPI yöntemi seçme

**Önceden Hazır Ayarlar** bölümündeki listeden veya menü çubuğu > **DPI Yöntemi**'nden seçin. Seçim kaydedilir ve uygulama yeniden açıldığında korunur. ByeDPI çalışıyorsa yeni yöntemle otomatik yeniden başlar. Yeni yöntem başlatılamazsa ByeDPI önceki yöntemle yeniden açılır; o da olmazsa sistem proxy kapatılır (internetiniz kesilmesin diye).

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
| Özel | Kendi parametreleriniz |

Split 2, listede ve menü çubuğunda **Split 2 (önerilen)** olarak görünür. Fake yöntemleri kaldırıldı: macOS'taki ciadpi sahte paket gönderemez. Fake veya bilinmeyen bir yöntem kayıtlıysa Split 2'ye dönülür.

**Neden Split 2?** Discord'un açılıştaki güncelleme denetimi en çok TLS 1.2 kullanır. TLS 1.2'de sunucu sertifikası şifresiz gittiği için operatörün DPI'ı bağlantıyı sertifikadan tanıyıp kesebilir. 28 Ekim 2026'da bir Türk operatöründe yapılan ölçümde Split 2 dışındaki tüm hazır yöntemler TLS 1.3'ü geçirdi, ama TLS 1.2 bağlantısı sunucunun ilk 1400 baytından sonra kesildi. Split 2 (ve `-s N` ile N≥2 olan parametreler) ikisini de geçirdi: `discord.com`, `updates.discord.com`, `gateway.discord.gg`, `cdn.discordapp.com`, `discordapp.com`, `www.roblox.com`, `clientsettings.roblox.com`, `apis.roblox.com`, `auth.roblox.com`. Ölçüm tek operatörde yapıldı; bağlantı testinde "Discord güncelleme denetimi" başarısızsa başka yöntemleri deneyin ve sonucu bildirin.

**Standart** artık varsayılan değil ama seçilebilir. v1.1.1'den yükseltirken yönteminiz Standart ise bir kez Split 2'ye geçirilirsiniz ve durum mesajı bunu söyler. Standart'ı yeniden seçerseniz bir daha değiştirilmez.

Önerilen deneme sırası: önce **Split 2**; olmazsa Özel yöntemde `-s 3 --tlsrec 1+s`; sonra **Standart**, **Disorder**, **Split + Disorder**, **Disorder SNI**, **OOB**. Son gruptaki yöntemler ölçümde TLS 1.2'yi geçirmedi; bunlardan birini seçerseniz bağlantı testinde "Discord güncelleme denetimi" satırına bakın. Bir site açılmıyorsa önce DNS uyarısını kontrol edin; sorun çoğu zaman DNS'tir.

### Özel (Custom) parametreler

1. **Özel Parametreleri Düzenle**'ye basın: Özel moda geçilir. Kaydettiğiniz özel parametreler korunur; metin kutusu yalnızca boşsa veya hazır yöntemlerden biriyle aynıysa seçili yöntemin parametreleriyle doldurulur.
2. Metin kutusuna ciadpi parametrelerini yazın (ör. `-s 3 --tlsrec 1+s`). Birden çok satır ve tırnaklı değerler desteklenir.
3. **Uygula**'ya basın. ByeDPI çalışıyorsa bu parametrelerle yeniden başlar. Parametreler boşsa ByeDPI önceki yöntemle çalışmaya devam eder.

`-i 127.0.0.1`, `-p 1080` ve `-G` otomatik eklenir. Bunları kendiniz yazarsanız sizinki kullanılır; değiştirmeniz önerilmez (uygulamanın geri kalanı 127.0.0.1:1080 varsayar). `-G` (`--http-connect`), sistem HTTPS proxy'sinin, Hızlı İşlemler'in verdiği `HTTPS_PROXY`'nin ve bağlantı testinin kullandığı HTTP CONNECT isteklerini aynı portta kabul eder; SOCKS5 bağlantılarını etkilemez. Parametreler kaydedilir.

### Hızlı İşlemler (uygulama başlatma)

- **Uygulama ekle:** Hızlı İşlemler başlığındaki **+** > **Applications Klasöründen Seç**.
- **Başlat:** Uygulama simgesine tıklayın. ByeDPI kapalıysa önce otomatik başlatılır, ardından uygulama proxy parametresi ve proxy ortam değişkenleriyle açılır. Uygulama zaten açıksa **Kapat ve Yeniden Başlat** önerilir: parametre ve ortam değişkenleri yalnızca yeni başlatılan uygulamaya verilebilir.
- **Düzenle / Kaldır:** Simgenin üzerine gelince çıkan kalem ve çarpı düğmeleri. Varsayılan başlatma parametresi `--proxy-server=socks5://127.0.0.1:1080`'dir (**Roblox'u Hızlı İşlemler'e Ekle** ile eklenen Roblox'ta boştur: Roblox bu parametreyi kullanmaz); **Varsayılana Sıfırla** ile geri dönebilirsiniz. Ortam değişkenleri düzenlenemez; her uygulamaya verilir.
- DNS engeli algılanmışken bir uygulama başlatırsanız durum mesajı bunu söyler: DNS düzeltilmeden bağlanılamaz.

#### Proxy parametresi ve HTTPS_PROXY

Hızlı İşlemler'den açılan her uygulamaya iki şey verilir:

| | Değer | Kim kullanır? |
|---|---|---|
| Proxy parametresi | `--proxy-server=socks5://127.0.0.1:1080` | Chromium/Electron ağ katmanı: Discord pencereleri, Chrome, Brave, Edge, Slack, Spotify… |
| Ortam değişkenleri | `HTTPS_PROXY` ve `https_proxy` = `http://127.0.0.1:1080`; `NO_PROXY` ve `no_proxy` = `localhost,127.0.0.1,::1` | Discord'un güncelleme denetimi, Roblox (libcurl) ve bu değişkeni okuyan diğer programlar |

- Discord'un güncelleme denetimi `--proxy-server` parametresini kullanmaz; 0.0.419'dan önceki sürümleri macOS sistem proxy'sini de okumaz; hepsi `HTTPS_PROXY`'yi okur. Discord bu denetim başarılı olmadan açılmadığı için ikisi de gerekir ([#15](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/15)).
- `HTTPS_PROXY`, ByeDPI'ın aynı porttaki HTTP CONNECT desteğini (`-G`) kullanır. `HTTP_PROXY` ve `ALL_PROXY` bilerek verilmez: ciadpi düz HTTP proxy'si değildir, şifresiz HTTP istekleri bozulurdu.
- Ortam değişkenleri uygulamanın alt süreçlerine de geçer. ByeDPI'ı durdurduğunuzda bu uygulamaları kapatıp normal şekilde açın.
- Çalışan ByeDPI uygulama dışında (ör. eski bir sürümle) `-G` olmadan başlatılmışsa uygulama yine açılır ama SplitWire uyarır: Discord'un güncelleme denetimi gibi bağlantılar geçemez. ByeDPI'ı durdurup yeniden başlatın.

Safari gibi macOS proxy ayarlarını kullanan uygulamalar için [Sistem Proxy](#sistem-proxy)'yi (SOCKS + HTTPS), Roblox için [Roblox yolunu](#roblox), hiçbirini kullanmayan oyunlar için [WireGuard](#wireguard--cloudflare-warp)'ı kullanın.

#### Kendini yeniden başlatan uygulamalar

Discord güncellemeyi kurduktan sonra yeni sürümü parametresiz ve ortam değişkensiz açar; yeni sürüm yine "Checking for updates…" ekranında kalırdı. SplitWire bunu algılar:

- Hızlı İşlemler'den açılan bir uygulama kapandıktan sonra 30 saniye içinde aynı uygulamanın yeni bir örneği açılırsa SplitWire bunu kendi kendine yeniden başlatma sayar, yeni örneği sormadan kapatır ve uygulamayı ByeDPI ile yeniden açar. Durum mesajı bunu söyler.
- Döngüye karşı aynı uygulama için 10 dakikada en çok 3 kez yapılır.
- Yeni örnek parametrelerle zaten açıldıysa dokunulmaz; bu durum 3 kezlik sınıra sayılmaz.
- ByeDPI çalışmıyorsa yeniden açılmaz; durum mesajı ByeDPI'ı başlatıp uygulamayı Hızlı İşlemler'den açmanızı söyler.
- Uygulamayı kendiniz kapatıp 30 saniye içinde Dock'tan açarsanız bu da yeniden başlatma sayılır ve uygulama ByeDPI ile yeniden açılır. 30 saniyeden sonra açarsanız karışılmaz (o zaman proxy de kullanılmaz).
- Roblox için çalışmaz: macOS, Roblox açıldığında bildirim göndermez ([Roblox nasıl yeniden başlatılır](#roblox-nasıl-yeniden-başlatılır)). Roblox'u her zaman Hızlı İşlemler'den başlatın.

### Gelişmiş

ByeDPI sekmesinin en altındaki **Gelişmiş** bölümü, Discord "Checking for updates…" ekranında kalıyorsa yapılacakları özetler ([Sorun giderme](#sorun-giderme)). **Discord Günlüklerini Aç** düğmesi Discord'un günlük klasörünü (`~/Library/Application Support/discord/logs`) Finder'da açar; sorun bildirirken günlükleri ekleyin.

v1.1.1'e kadar bu bölümde önerilen `SKIP_HOST_UPDATE` / `SKIP_MODULE_UPDATE` ayarları kaldırıldı: güncel macOS Discord'da etkisizdir, gerek yoktur.

---

## Roblox

Ölçümlere göre Roblox'un web/giriş adresleri (`www.roblox.com`, `clientsettings.roblox.com`, `gamejoin.roblox.com`, `apis.roblox.com`) Discord ile aynı şekilde engelleniyor: Operatör DNS'i engelleme adresi (`195.175.254.2`) döndürüyor, doğru adresle bile doğrudan TLS bağlantısı DPI'a takılıyor; ByeDPI üzerinden ise erişilebiliyor ([#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13)).

Roblox'un macOS istemcisi (libcurl) `--proxy-server` parametresini de macOS sistem proxy'sini de kullanmaz; v1.1.1'deki Sistem Proxy yolunun işe yaramamasının nedeni buydu. Ama `HTTPS_PROXY` ortam değişkenini okur ve [Hızlı İşlemler](#proxy-parametresi-ve-https_proxy) bunu verir. Bu şekilde başlatılan Roblox'un tüm HTTPS trafiği (`apis`, `auth`, `clientsettings`, `gamejoin`, `ecsv2`, `realtime-signalr` … `.roblox.com`) ByeDPI'dan geçer. Proxy olmadan Roblox'un günlüklerinde `SslConnectFail` (bağlantı TLS sırasında kesiliyor, ör. `ecsv2.roblox.com`: SNI engeli) ve `TlsVerificationFail` (ad engelleme adresine çözülüyor) hataları görünür ve giriş yapılamaz.

Şifreyle girişte ikinci bir adım var: şifreyi gönderdikten sonra, giriş tamamlanmadan önce Roblox bir güvenlik doğrulaması ("Security" ekranı) gösterir ve bunu macOS'un web görünümünde açar (`https://www.roblox.com/challenge/…`). Bu web görünümü `HTTPS_PROXY`'yi değil, yalnızca macOS sistem proxy'sini kullanır. Sistem proxy kapalıyken `www.roblox.com` engellendiği için sayfa yüklenmez, "Security" ekranı boş kalır ve giriş ilerlemez. Doğrulamadaki captcha sağlayıcıları (Arkose Labs, hCaptcha) engelli değildir.

1. Önce DNS'i düzeltin: **Ağ Ayarları**'ndan 1.1.1.1 veya [şifreli DNS (DoH) profili](#şifreli-dns-doh-profili). DNS uyarısı Roblox'u da kontrol eder.
2. Roblox'u Hızlı İşlemler'e ekleyin ve her zaman oradan başlatın. Roblox kuruluysa ve Hızlı İşlemler'de yoksa ByeDPI sekmesindeki Roblox notunda **Roblox'u Hızlı İşlemler'e Ekle** düğmesi görünür; bu düğme Roblox'u proxy parametresi olmadan ekler (Roblox onu kullanmaz, `HTTPS_PROXY` yeterli). **+** > **Applications Klasöründen Seç** ile `Roblox.app`'i seçerek de ekleyebilirsiniz. Roblox açıksa SplitWire onu (menü çubuğundaki Roblox simgesiyle birlikte) kapatıp yeniden açar ([ayrıntılar](#roblox-nasıl-yeniden-başlatılır)).
3. Şifreyle giriş yaparken [Sistem Proxy](#sistem-proxy)'yi de açın. Giriş yaptıktan sonra kapatabilirsiniz; "Security" ekranı yine boş kalırsa tekrar açın. Sistem Proxy kapalıyken Roblox'u Hızlı İşlemler'den başlatırsanız (DNS uyarısı yoksa) durum mesajı bunu hatırlatır: "Roblox ByeDPI proxy ile başlatıldı. Şifreyle giriş yapacaksanız güvenlik doğrulaması için Sistem Proxy'yi de açın."
4. Oyunlara Roblox uygulamasının içinden girin. Roblox'u menü çubuğundan tamamen kapattıysanız tarayıcıdaki **Oyna** düğmesi onu proxy'siz açar; o zaman Roblox'u kapatıp Hızlı İşlemler'den yeniden açın.

- Yalnızca Roblox'un web ve giriş trafiği ByeDPI'dan geçer. Oyun trafiği (UDP) doğrudan Roblox oyun sunucularına gider, proxy'den geçmez; bu yüzden proxy ping eklemez. Ölçümde ByeDPI üzerinden oyuna katılma başarılı oldu ve yeniden katılınca farklı bir sunucuya girildi: sunucu değiştirmek normal çalışır. (WARP/WireGuard ile [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13)'teki bir kullanıcı yalnızca tek bir sunucuya girebildi ve ping yüksekti.)
- [Bağlantı testindeki](#bağlantı-testi) **Roblox** satırı, Roblox'un ayar sunucusuna (`clientsettings.roblox.com`) ByeDPI üzerinden ulaşılıp ulaşılamadığını gösterir.
- Bu bölümdeki davranış 28 Ekim 2026'da tek bir Mac'te (macOS 27, Roblox 0.745.0.7451137), bir Türk operatöründe ölçüldü; başka operatörlerde farklı olabilir. Ping değerleri ölçülmedi. İşe yarasa da yaramasa da sonucu [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13) üzerinden bildirirseniz çok yardımcı olur.
- İşe yaramazsa [WireGuard](#wireguard--cloudflare-warp) kullanın. Tüm trafik WARP'tan geçtiği için ping daha yüksek olabilir ve bazı oyunlarda sunucu değiştirme sorunları yaşanabilir.

### Roblox nasıl yeniden başlatılır

Roblox ile menü çubuğundaki Roblox uygulaması (`Roblox.app` içindeki `RobloxMenuBar.app`) birbirini yaklaşık bir saniye içinde yeniden açar; kapatılan Roblox penceresiz olarak (menü çubuğu modunda) geri gelir. Yeni açılan örnek, onu açan sürecin ortam değişkenlerini alır: menü çubuğu uygulaması açık kalırsa Roblox'u `HTTPS_PROXY` olmadan geri açar. Menü çubuğu uygulaması çalışmıyorken Roblox'u kapatmak ise yalnızca penceresini kapatır; Roblox arka planda çalışmaya devam eder.

Bu yüzden Roblox'u Hızlı İşlemler'den başlattığınızda SplitWire:

- Menü çubuğu uygulamasını da kapatır. Roblox kapalı, yalnızca menü çubuğu uygulaması açıksa bunu sormadan yapar.
- Geri açılan örneklere kapatma isteğini yeniden gönderir.
- Roblox 3 saniye içinde kapanmazsa "Zorla kapatılsın mı?" diye sormadan zorla kapatır: **Kapat ve Yeniden Başlat**'ı zaten onayladınız ve oyun ilerlemesi sunucuda tutulur.
- Roblox'u `HTTPS_PROXY` ile açar. Bu Roblox'un açtığı menü çubuğu uygulaması da değişkeni alır.

Ölçümde başka bir proxy ayarıyla açılmış Roblox ve menü çubuğu uygulaması 2,9 saniyede, penceresi kapatılmış (arka planda çalışan) Roblox 5,3 saniyede proxy'li yeni örnekle değiştirildi.

[Kendini yeniden başlatan uygulamalar](#kendini-yeniden-başlatan-uygulamalar) özelliği Roblox'u kapsamaz: Roblox'un `Info.plist` dosyasında `LSUIElement` açık olduğu için macOS, Roblox açıldığında SplitWire'a bildirim göndermez. Roblox proxy'siz açıldıysa (ör. tarayıcıdan) onu Hızlı İşlemler'den yeniden başlatın.

---

## Sistem Proxy

macOS proxy ayarlarını kullanan ama proxy parametresini desteklemeyen uygulamalar (ör. Safari) için sistem genelinde proxy ayarı: hem **SOCKS proxy** hem de **güvenli web proxy'si (HTTPS)** `127.0.0.1:1080`'i gösterir.

- Roblox'un kendisi bu ayarı kullanmaz (onu [Hızlı İşlemler'den başlatın](#roblox)), ama şifreyle girişteki güvenlik doğrulaması kullanır: Roblox bu doğrulamayı macOS'un web görünümünde açar ve Sistem Proxy kapalıyken "Security" ekranı boş kalır. Şifreyle giriş yaparken açın; giriş yaptıktan sonra kapatabilirsiniz.
- Discord 0.0.419 ve sonrası bu ayarı da okur: ByeDPI çalışırken Sistem Proxy açıksa Dock'tan veya oturum açılışında başlayan Discord da ByeDPI'dan geçer. Güncelleme denetimi yine en çok TLS 1.2 kullandığı için Split 2 gerekir.

1. ByeDPI'ı başlatın.
2. **Hızlı İşlemler > Sistem Proxy > Aç** ve yönetici parolanızı girin. Birincil ağ servisinizde (ör. Wi-Fi) SOCKS ve HTTPS proxy tek seferde `127.0.0.1:1080` olarak açılır. Düz web proxy'si (HTTP) ve proxy istisna (bypass) listesi değiştirilmez; ciadpi düz HTTP proxy isteklerini karşılayamadığı için HTTP proxy hiç kullanılmaz.
3. Kapatmak için aynı pencerede **Kapat** veya menü çubuğu > **Sistem Proxy'yi Kapat**.

Önemli:

- Sistem proxy yalnızca ByeDPI çalışırken güvenlidir. ByeDPI kapalıyken açık kalırsa **internet çalışmaz**.
- Proxy açılırken yönetici komutu ByeDPI'ın hâlâ dinlediğini kontrol eder; parola penceresi açıkken ByeDPI durduysa proxy açılmaz.
- Uygulama, herhangi bir serviste SOCKS **veya** HTTPS proxy açık ve `127.0.0.1:1080`'i gösteriyorsa bunu "kendi proxy'si" sayar. Kapatırken yalnızca bizi gösteren ayarları kapatır; başka bir sunucuya ayarlı kendi proxy'nize dokunmaz.
- v1.1.0 ile açılmış (yalnızca SOCKS) ayar da algılanır ve otomatik kapatılır. Sistem Proxy penceresinde "yalnızca bir kısmı açık" notu görünüyorsa ByeDPI çalışırken **Aç**'a basın; HTTPS proxy de eklenir (başka ağ servislerinde kalmış yarım ayarlar dahil, tek parola penceresinde).
- Birincil serviste başka bir sunucuyu gösteren kendi SOCKS veya HTTPS proxy'niz (ör. şirket veya okul proxy'si) açıksa **Aç** onun üzerine yazmaz ve uyarır. Sistem proxy'yi kullanmak için önce o proxy'yi Sistem Ayarları > Ağ > (servis) > Ayrıntılar > Proxy'ler bölümünden kapatın.
- Uygulama dışında (ör. eski sürümle) başlatılmış bir ByeDPI `-G` olmadan çalışıyorsa sistem proxy açılmaz; ByeDPI'ı durdurup yeniden başlatın.
- Uygulama proxy'yi şu durumlarda otomatik kapatır (yönetici parolası istenir; pencere nedenini yazar): ByeDPI'ı durdurduğunuzda, **Tümünü Zorla Kapat**'ta ve uygulamadan çıkarken.
- ByeDPI çökerse uygulama uyarır ve **Yeniden Başlat** veya **Sistem Proxy'yi Kapat** seçeneklerini sunar.
- Uygulama açılırken proxy açık ama ByeDPI çalışmıyorsa sizi uyarır.
- ByeDPI'ı durdururken parola penceresini iptal ederseniz proxy açık kalır ve uygulama uyarı gösterir. Sistem Proxy penceresindeki kırmızı **Kapat** düğmesine (veya menü çubuğu > **Sistem Proxy'yi Kapat**) basın ya da ByeDPI'ı yeniden başlatın.
- Çıkışta proxy kapatılamazsa (parola iptal edildi veya hata) uygulama hemen çıkmaz ve sorar:
  - **Tekrar Dene:** Parola penceresi yeniden açılır.
  - **ByeDPI çalışsın, çık:** Uygulama kapanır, ByeDPI arka planda çalışmaya devam eder; internet çalışır. Uygulamayı yeniden açınca ByeDPI'ı durdurup proxy'yi kapatabilirsiniz.
  - **Çıkma:** Uygulama açık kalır.

  Oturum kapatma, yeniden başlatma ve bilgisayarı kapatma sırasında bu soru sorulmaz; proxy açık kalmışsa uygulama bir sonraki açılışta uyarır.
- Elle kapatma: [Sorun giderme](#proxy-açık-kaldı-internet-çalışmıyor).

---

## DNS ayarları

### DNS engellemesi uyarısı

Uygulama açılışta Discord (`discord.com`, `gateway.discord.gg`) ve Roblox (`www.roblox.com`) adlarını sistem DNS'i ile çözer:

- Discord adları ayrıca şifreli DNS (Cloudflare/Google DoH) ile çözülür ve sonuçlar karşılaştırılır. Sistem DNS'i engelleme sayfası adresi (ör. `195.175.254.2`) veya ilgisiz bir adres döndürüyorsa uyarı gösterilir.
- Roblox için gerçek adres doğrulanmaz; yalnızca engelleme adreslerine bakılır: bilinen engelleme adresi (`195.175.254.2`), aynı kontrolde Discord'un zehirli bulunduğu adres ve `0.0.0.0` / `127.x`. Roblox'un CDN adresleri çözümleyicinin konumuna göre değişebildiği için başka bir adres yanlış alarm üretmez.

Sorun varsa ByeDPI ve Ağ Ayarları sekmelerinin üstünde turuncu uyarı görünür ve hangi servislerin etkilendiğini söyler (ör. "Discord ve Roblox için…"). Karar verilemiyorsa (ör. şifreli DNS'e ulaşılamadı) uyarı gösterilmez; yalnızca IPv4 adresleri karşılaştırılır.

Neden önemli: ciadpi bağlanacağı adresi (SOCKS ve HTTPS proxy bağlantılarında) sistem DNS'i ile bulur. DNS engelleme adresi döndürüyorsa DPI aşılsa bile Discord'a veya Roblox'a bağlanılamaz. Bu durumda [bağlantı testinde](#bağlantı-testi) hiçbir satır geçmez ve teşhis önce DNS'i düzeltmenizi söyler; Hızlı İşlemler'den uygulama başlatırken de durum mesajı uyarır.

### DNS sunucusu seçme

**Ağ Ayarları** sekmesi:

- **Mevcut DNS:** Kullanılan ağ servisi (ör. "Wi-Fi (en0)") ve DNS sunucuları. DHCP kullanılıyorsa gerçekte kullanılan sunucular da gösterilir. **Yenile** ile tekrar okunur.
- **DNS Sunucusu Seç:**
  - **Cloudflare (1.1.1.1, 1.0.0.1) — Önerilen**
  - **Google (8.8.8.8, 8.8.4.4)**
  - **Quad9 (9.9.9.9, 149.112.112.112)**
  - **DHCP'ye Sıfırla:** Ağın (modemin) verdiği DNS'e döner.
  - **DNS Önbelleğini Temizle**

Seçim, birincil ağ servisine uygulanır ve DNS önbelleği temizlenir (yönetici parolası istenir). Birkaç saniye sonra DNS kontrolü otomatik tekrarlanır.

DNS'i 1.1.1.1 yaptığınız halde uyarı sürüyorsa operatörünüz 53. port DNS trafiğini yakalayıp kendi cevabını döndürüyordur. Bu durumda DoH profilini kullanın.

---

## Şifreli DNS (DoH) profili

DNS over HTTPS (DoH), DNS sorgularını Cloudflare'e HTTPS (443. port) üzerinden şifreli gönderir; operatörün DNS müdahalesi bunu etkilemez. Profil tüm sistem için geçerlidir. Uygulama profili **kendisi yüklemez**; yüklemeyi siz onaylarsınız.

### Yükleme

1. **Ağ Ayarları** sekmesi > **Şifreli DNS (DoH) Profili…** (veya uyarı kutusundaki aynı düğme).
2. **Profili Oluştur ve Aç**'a basın. Profil `~/Downloads/SplitWire-Cloudflare-DoH.mobileconfig` olarak kaydedilir ve macOS'a açtırılır ("Profil indirildi" bildirimi görünür).
3. Profili Sistem Ayarları'nda bulun (**Aygıt Yönetimi'ni Aç** düğmesi bu bölmeyi açar):
   - **macOS 15 ve sonrası:** Sistem Ayarları > **Genel > Aygıt Yönetimi**
   - **macOS 13–14:** Sistem Ayarları > **Gizlilik ve Güvenlik > Profiller**
4. **"SplitWire – Cloudflare DNS over HTTPS"** profiline çift tıklayın, **Yükle**'ye basın ve parolanızı girin.
5. Uygulamaya dönün ve **Tekrar Kontrol Et**'e basın (pencereyi **Kapat** ile kapatınca kontrol otomatik tekrarlanır).

### Kaldırma

Aynı bölmede (macOS 15+: Genel > Aygıt Yönetimi; macOS 13–14: Gizlilik ve Güvenlik > Profiller) profili seçin ve **–** (Kaldır) düğmesine basın.

---

## WireGuard / Cloudflare WARP

Bu mod Mac'in **tüm** internet trafiğini ve DNS sorgularını ücretsiz Cloudflare WARP üzerinden geçirir. ByeDPI ile çalışmayan uygulamalar (oyunlar vb.) için kullanışlıdır. macOS'ta uygulama bazlı bölünmüş tünel (yalnızca Discord gibi) desteklenmez.

Tüm trafik tünelden geçtiği için çevrim içi oyunlarda gecikme (ping) artar ve bazı oyunlarda sunucu değiştirme sorunları yaşanabilir ([#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13)). Roblox için önce [ByeDPI yolunu](#roblox) deneyin: Orada yalnızca Roblox'un web ve giriş trafiği proxy'den geçer, oyun trafiği doğrudan sunucuya gider.

### Gereksinimler

1. [Homebrew](https://brew.sh) kurulu olmalı.
2. Terminal'de:
   ```bash
   brew install wireguard-tools
   ```
   Bu paket `wg-quick`, `wg`, `wireguard-go` ve gerekli bash 4+ sürümünü kurar. WireGuard sekmesindeki **Gereksinimler** bölümü eksik aracı gösterir; **Komutu Kopyala** komutu panoya kopyalar.
3. `wgcf` ayrıca kurulmak zorunda değildir: Homebrew'daki (`/opt/homebrew/bin/wgcf` veya `/usr/local/bin/wgcf`) ya da `~/.local/bin/wgcf` kullanılır; yoksa kurulum sırasında GitHub'dan indirilir.

### Kurulum

1. **WireGuard** sekmesi > **Kur ve Bağlan**.
2. Uygulama sırasıyla:
   - `wgcf`'yi hazırlar. İndirme gerekirse bu Mac'in işlemcisine (Apple Silicon/Intel) uygun dosyayı indirir ve dosyanın bu işlemci için bir macOS programı olduğunu ve SHA-256 özetini doğrular. Önce SHA-256 özeti uygulamaya gömülü sabit sürüm (v2.3.0) denenir; daha yeni bir sürüm yalnızca yedek olarak ve GitHub özetini veriyorsa kullanılır. Özeti bilinmeyen dosya kabul edilmez. v1.0.0'dan kalma bozuk `~/.local/bin/wgcf` dosyası otomatik değiştirilir.
   - Ücretsiz bir Cloudflare WARP hesabı kaydeder (Cloudflare WARP koşulları kabul edilir) ve WireGuard profilini oluşturur.
   - WARP sunucusunun adını şifreli DNS (DoH) ile çözer ve yapılandırmaya IP adresi olarak yazar (operatör DNS'i zehirli olsa da doğru sunucuya gidilir, açılışta DNS gerekmez). Çözülemezse ad olduğu gibi kalır.
   - Yönetici parolanızı **bir kez** ister; yapılandırmayı `/etc/wireguard/wgcf.conf` konumuna kurar ve tüneli açar. **Açılışta otomatik bağlan** seçiliyse bir LaunchDaemon da ekler (aşağıya bakın).
3. Durum **Bağlı** olduğunda arayüz adı (ör. `utun5`) görünür.

### Açılışta otomatik bağlanma (isteğe bağlı)

**İşlemler** bölümündeki **Açılışta otomatik bağlan** kutusu varsayılan olarak **kapalıdır**.

- **Kapalı:** LaunchDaemon kurulmaz; tünel bilgisayar açılınca başlamaz. Yeniden başlattıktan sonra **Bağlan**'a basın (parola sorulur).
- **Açık:** `/Library/LaunchDaemons/com.splitwire.wireguard.plist` kurulur ve tünel her açılışta parola sorulmadan başlar.
- Değişiklik **Kur ve Bağlan** / **Yeniden Kur** ile uygulanır. Kutu kapalıyken yeniden kurmak var olan LaunchDaemon'ı kaldırır.

> **Güvenlik uyarısı:** Bu seçenek açıkken Homebrew'un `wg-quick`, `bash`, `wg` ve `wireguard-go` programları her açılışta root (yönetici) olarak çalışır. Bu dosyaları kullanıcı hesabınız değiştirebildiğinden, hesabınızda çalışan kötü amaçlı bir program bunu yönetici yetkisi elde etmek için kullanabilir. Gerçekten gerekmiyorsa kapalı bırakın.

### Günlük kullanım

- **Bağlantıyı Kes:** Tüneli kapatır (parola sorulur). Açılışta otomatik bağlanma açıksa bilgisayar yeniden başlatıldığında tekrar bağlanır; kapalıysa siz **Bağlan**'a basana kadar bağlanmaz.
- **Bağlan:** Kesilmiş tüneli tekrar açar (parola sorulur).
- **Yeniden Kur:** Profili yeniden oluşturup kurar (mevcut WARP hesabı kullanılır; hesap geçersizse yeni hesap oluşturmayı önerir ve eski hesap dosyasını yedekler). **Açılışta otomatik bağlan** seçimi de bu sırada uygulanır.
- **WireGuard'ı Kaldır:** Tüneli kapatır, varsa otomatik başlatmayı ve sistem yapılandırmasını siler. İsterseniz **Cloudflare hesabını da sil** kutusunu işaretleyin.
- WARP bağlıyken ByeDPI'a gerek yoktur.

### Dosya konumları

| Dosya | Açıklama |
|---|---|
| `~/.local/bin/wgcf` | İndirilen wgcf (Homebrew'dan kurulduysa orası kullanılır) |
| `~/.config/wireguard/wgcf-account.toml` | Cloudflare WARP hesabı |
| `~/.config/wireguard/wgcf-profile.conf`, `wgcf.conf` | Oluşturulan WireGuard profili |
| `/etc/wireguard/wgcf.conf` | Sistemin kullandığı yapılandırma (root, 600) |
| `/Library/LaunchDaemons/com.splitwire.wireguard.plist` | Açılışta otomatik başlatma (yalnızca seçenek açıksa) |
| `/var/log/splitwire-wireguard.log` | Otomatik başlatma günlüğü (yalnızca seçenek açıksa) |

---

## Dock simgesi, dil ve koyu mod

### Dock simgesini gizleme

- Pencerenin üstündeki **Dock simgesini gizle** kutusunu işaretleyin veya menü çubuğu > **Dock simgesini gizle**.
- Ayar kaydedilir ve sonraki açılışlarda da geçerlidir.
- Dock simgesi gizliyken uygulama yalnızca menü çubuğundaki kalkan simgesinden kullanılır (⌘Tab listesinde görünmez). Pencere için: menü çubuğu > **Ana Pencereyi Göster**.
- Uygulamanın oturum açınca başlamasını isterseniz: Sistem Ayarları > Genel > **Giriş Öğeleri** bölümüne SplitWire-Turkey'i ekleyin. (ByeDPI otomatik başlamaz; menü çubuğundan başlatın.)

### Dil değiştirme

- Pencerenin sağ üstündeki seçiciden **Türkçe** veya **English** seçin. Pencere ve menü çubuğu anında yeni dile geçer; seçim kaydedilir.
- macOS'un kendi menüleri ve pencereleri (uygulama menüsündeki Gizle/Çık, Düzen, Pencere menüleri, sistem panelleri) **bir sonraki açılışta** seçilen dile geçer. Bunun için uygulama, seçiminiz sistem dilinden farklıysa yalnızca kendisi için macOS dil tercihini (`AppleLanguages`) ayarlar; sistem geneline dokunmaz.
- İlk açılışta, sistem diliniz Türkçe ise Türkçe, değilse İngilizce kullanılır.
- v1.0.0'daki "Русский" seçeneği kaldırıldı (çevirisi yoktu); bu seçimi yapmış olanlar İngilizce arayüzle devam eder.

### Koyu mod

Pencerenin sağ üstündeki anahtar. Seçim kaydedilir.

---

## Sorun giderme

### Uygulama açılmıyor

- **"Geliştirici doğrulanamadı":** [İlk açılış](#gatekeeper-uyarısı-ilk-açılış) adımlarını uygulayın.
- **"Hasar görmüş, Çöp Sepeti'ne taşıyın":** v1.0.0'a özgü bir imza sorunuydu. v1.1.0'ı indirin. Yine görürseniz `xattr -dr com.apple.quarantine /Applications/SplitWire-Turkey.app` komutunu çalıştırın.

### Discord "Checking for updates…" ekranında kalıyor veya "update failed" diyor

Discord açılışta güncelleme denetimi yapar ve bu denetim başarılı olmadan açılmaz. Denetim `--proxy-server` parametresini kullanmaz; 0.0.419'dan önceki sürümleri macOS sistem proxy'sini de okumaz; hepsi `HTTPS_PROXY`'yi okur. Denetim en çok TLS 1.2 kullanır ([#15](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/15)). Sırayla:

1. **DNS:** DNS uyarısı varsa önce [DNS ayarları](#dns-ayarları) adımlarını uygulayın.
2. **Bağlantı testi:** **ByeDPI Durumu** bölümünde **Test Et** / **Tekrar Test Et**'e basın ([bağlantı testi](#bağlantı-testi)). Yalnızca "Discord güncelleme denetimi (TLS 1.2)" başarısızsa seçili yöntem TLS 1.2'yi geçirmiyordur: **Split 2 (önerilen)**'yi seçin. Zaten Split 2'deyseniz Özel yöntemde ör. `-s 3 --tlsrec 1+s` deneyin.
3. **Yeniden başlatma:** Discord'u Hızlı İşlemler'den yeniden başlatın. Dock'tan, Spotlight'tan veya v1.1.1 ve öncesiyle başlatılmış Discord'a `HTTPS_PROXY` verilmemiştir.
4. Çalışan ByeDPI uygulama dışında (ör. eski bir sürümle) `-G` olmadan başlatılmışsa güncelleme denetimi geçemez ve SplitWire bunu söyler: ByeDPI'ı durdurup yeniden başlatın.
5. Hâlâ olmuyorsa **Gelişmiş > Discord Günlüklerini Aç** ile günlük klasörünü açın ve günlükleri issue'ya ekleyin. Gerekirse [WireGuard](#wireguard--cloudflare-warp) modunu deneyin.

Eski rehberlerdeki `SKIP_HOST_UPDATE` / `SKIP_MODULE_UPDATE` ayarları güncel macOS Discord'da etkisizdir; gerek yoktur.

### Roblox bağlanmıyor

1. DNS uyarısını kontrol edin ve [DNS ayarları](#dns-ayarları) adımlarını uygulayın.
2. Roblox'u Hızlı İşlemler'den başlattığınızdan emin olun ([Roblox](#roblox)). Dock'tan, Launchpad'den veya tarayıcıdaki **Oyna** ile açılan Roblox proxy kullanmaz. Sistem Proxy bunu düzeltmez: Roblox'un kendisi sistem proxy'sini kullanmaz.
3. Şifreyle girişte "Security" ekranı boş kalıyor veya giriş ilerlemiyorsa ByeDPI çalışırken [Sistem Proxy](#sistem-proxy)'yi açın ve girişi yeniden deneyin. Güvenlik doğrulaması yalnızca sistem proxy'sini kullanır.
4. Bağlantı testinde **Roblox** başarısızsa başka bir DPI yöntemi deneyin.
5. Hâlâ olmuyorsa [WireGuard](#wireguard--cloudflare-warp) modunu deneyin ve sonucu [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13) üzerinden bildirin.

### Terminal'den bağlantı testi

ByeDPI çalışırken:

```bash
curl -I --socks5-hostname 127.0.0.1:1080 https://discord.com
curl -I --proxy http://127.0.0.1:1080 https://www.roblox.com                  # HTTPS proxy (HTTP CONNECT)
curl -I --tls-max 1.2 --proxy http://127.0.0.1:1080 https://updates.discord.com # TLS 1.2 (Discord'un güncelleme denetimi gibi)
```

`HTTP/2 200` (veya benzeri bir HTTP yanıtı) görürseniz proxy ve DNS çalışıyordur. Yalnızca son komut başarısızsa yöntem TLS 1.2'yi geçirmiyordur.

### "Port 1080 kullanımda"

- Önceki oturumdan kalmış bir ciadpi varsa uygulama **Süreçleri Kapat ve Tekrar Dene** seçeneğini sunar.
- Başka bir program kullanıyorsa hata mesajında programın adı ve PID'si yazar; o programı kapatın.
- **Tümünü Zorla Kapat** tüm ciadpi süreçlerini kapatır.

Terminal'den kontrol:

```bash
lsof -nP -iTCP:1080 -sTCP:LISTEN   # 1080'i kim dinliyor?
pkill -9 -x ciadpi                 # ciadpi normal kill sinyalini yok sayar, -9 gerekir
```

### Proxy açık kaldı, internet çalışmıyor

1. SplitWire'ı açın: Açılışta durumu algılar ve **Sistem Proxy'yi Kapat** seçeneğini sunar.
2. Elle: **Sistem Ayarları > Ağ** > bağlı olduğunuz servis (Wi-Fi veya Ethernet) > **Ayrıntılar…** > **Proxy'ler** > **SOCKS proxy** ve **Güvenli web proxy'si (HTTPS)** seçeneklerini kapatın > **Tamam**.
3. Terminal ile:
   ```bash
   networksetup -listallnetworkservices                       # servis adlarını listeler
   networksetup -getsocksfirewallproxy "Wi-Fi"                # SOCKS durumunu gösterir
   networksetup -getsecurewebproxy "Wi-Fi"                    # HTTPS durumunu gösterir
   sudo networksetup -setsocksfirewallproxystate "Wi-Fi" off  # SOCKS'u kapatır
   sudo networksetup -setsecurewebproxystate "Wi-Fi" off      # HTTPS'i kapatır
   ```

### DNS değişikliği uygulanmıyor

- **Ağ Ayarları** sekmesinde hangi servisin kullanıldığına bakın (ör. "Wi-Fi (en0)"). VPN açıksa birincil servis farklı görünebilir.
- `networksetup` hata verirse (ör. servis bulunamadı) hata metni Ağ Ayarları sekmesinde gösterilir.
- **DNS Önbelleğini Temizle**'ye basın, ardından **Tekrar Kontrol Et**.
- Terminal'den mevcut durum: `scutil --dns | head -20`

### WireGuard kurulamıyor

- **"wgcf: line 1: Not: command not found":** v1.0.0'ın indirdiği bozuk dosya. v1.1.0'da **Kur ve Bağlan**'a basmanız yeterli; dosya otomatik yeniden indirilir.
- **"WireGuard araçları gerekli":** `brew install wireguard-tools` çalıştırın ve tekrar deneyin. Homebrew yoksa önce [brew.sh](https://brew.sh) adresindeki talimatlarla kurun.
- **wgcf indirilemedi:** GitHub erişiminizi kontrol edin. Alternatif: `brew install wgcf` ile kurun; uygulama Homebrew'daki wgcf'yi otomatik kullanır.
- **Kurulum tamamlandı ama bağlı görünmüyor:** Birkaç saniye bekleyip durum yenileme düğmesine basın.
- **Bilgisayarı yeniden başlattıktan sonra bağlı değil:** **Açılışta otomatik bağlan** kapalıysa bu normaldir; **Bağlan**'a basın.
- Kurulum ve bağlantı hataları WireGuard sekmesinde gösterilir. Günlük (yalnızca açılışta otomatik bağlanma açıksa) ve durum (Terminal):
  ```bash
  cat /var/log/splitwire-wireguard.log
  sudo env PATH="$(brew --prefix)/bin:/usr/bin:/bin:/usr/sbin:/sbin" wg show
  ```

---

## Güncelleme

### v1.1.1'den yükseltme

1. v1.1.1'den çıkın (sistem proxy açıksa çıkarken kapatılır).
2. Yeni `SplitWire-Turkey.app`'i Uygulamalar klasöründeki eskisinin üzerine kopyalayın.

Tüm ayarlarınız korunur (favori uygulamalar, özel parametreler, dil). Tek değişiklik: yönteminiz Standart ise bir kez Split 2 yapılır ve durum mesajı bunu söyler. İsterseniz Standart'ı yeniden seçebilirsiniz; bir daha değiştirilmez.

- Discord açıksa Hızlı İşlemler'den bir kez yeniden başlatın: `HTTPS_PROXY` yalnızca yeni başlatılan uygulamaya verilebilir.
- Roblox için v1.1.1'de yalnızca Sistem Proxy'yi açtıysanız bu yetmez: Roblox'un kendisi sistem proxy'sini kullanmaz. Roblox'u Hızlı İşlemler'e ekleyip her zaman oradan başlatın ([Roblox](#roblox)). Sistem Proxy'yi şifreyle giriş yaparken açık tutun: güvenlik doğrulaması ("Security" ekranı) onu kullanır. Giriş yaptıktan sonra kapatabilirsiniz.
- Daha önce Gelişmiş bölümündeki tavsiyeyle Discord'un `settings.json` dosyasına `SKIP_HOST_UPDATE` / `SKIP_MODULE_UPDATE` eklediyseniz bunlar güncel macOS Discord'da etkisizdir.
- DNS hâlâ şart: DNS uyarısı görüyorsanız önce onu düzeltin.

Ayrıntılar: [RELEASE_NOTES_v1.1.2.md](RELEASE_NOTES_v1.1.2.md).

### v1.1.0'dan

1. v1.1.0'dan çıkın (sistem proxy açıksa çıkarken kapatılır).
2. Yeni `SplitWire-Turkey.app`'i Uygulamalar klasöründeki eskisinin üzerine kopyalayın.

Tüm ayarlarınız korunur. v1.1.0'da Sistem Proxy'yi kullanıyorsanız, HTTPS proxy'nin de açılması için ByeDPI'ı başlatıp **Sistem Proxy > Aç**'a yeniden basın. v1.1.0'dan kalan yalnızca-SOCKS ayarı da algılanır ve ByeDPI durduğunda otomatik kapatılır. [v1.1.1'den yükseltme](#v111den-yükseltme) notları da geçerlidir. Ayrıntılar: [RELEASE_NOTES_v1.1.1.md](RELEASE_NOTES_v1.1.1.md).

### v1.0.0'dan

1. v1.0.0'dan çıkın (menü çubuğu > Çıkış veya ⌘Q).
2. Yeni `SplitWire-Turkey.app`'i Uygulamalar klasöründeki eskisinin üzerine kopyalayın ve [ilk açılış](#gatekeeper-uyarısı-ilk-açılış) adımlarını uygulayın.

Ayarlarınız korunur: favori uygulamalar, koyu mod, dil ve menü çubuğunda seçtiğiniz DPI yöntemi taşınır. Kaldırılan Fake yöntemlerinden birini seçtiyseniz varsayılan yönteme (Split 2) dönülür. v1.0.0'ın işe yaramayan WireGuard klasör/tarayıcı ayarları silinir.

v1.0.0'da WireGuard kurulumu yarım kaldıysa v1.1.0'da **Kur ve Bağlan**'a basmanız yeterli; eski yapılandırma yenisiyle değiştirilir. v1.0.0'ın kurduğu otomatik başlatma (LaunchDaemon), **Açılışta otomatik bağlan** seçili değilse kaldırılır, seçiliyse yenisiyle değiştirilir.

---

## Tamamen kaldırma

1. Sistem proxy açıksa kapatın (menü çubuğu > **Sistem Proxy'yi Kapat**).
2. WireGuard kurduysanız **WireGuard** sekmesi > **WireGuard'ı Kaldır** (hesabı da silmek için kutuyu işaretleyin).
3. DoH profilini yüklediyseniz Sistem Ayarları'ndan kaldırın ([Kaldırma](#kaldırma)).
4. DNS'i değiştirdiyseniz **Ağ Ayarları > DHCP'ye Sıfırla**.
5. Uygulamadan çıkın ve `SplitWire-Turkey.app`'i Çöp Sepeti'ne taşıyın.
6. İsteğe bağlı, kalan dosyalar (Terminal):
   ```bash
   rm -f ~/.local/bin/wgcf
   rm -f ~/.config/wireguard/wgcf-account.toml* ~/.config/wireguard/wgcf-profile.conf ~/.config/wireguard/wgcf.conf
   rm -f ~/Downloads/SplitWire-Cloudflare-DoH.mobileconfig
   defaults delete com.cagritaskin.splitwire-turkey   # uygulama ayarları
   ```

WireGuard'ı uygulama olmadan elle kaldırmanız gerekirse:

```bash
sudo env PATH="$(brew --prefix)/bin:/usr/bin:/bin:/usr/sbin:/sbin" wg-quick down /etc/wireguard/wgcf.conf
sudo launchctl bootout system/com.splitwire.wireguard
sudo rm -f /Library/LaunchDaemons/com.splitwire.wireguard.plist /etc/wireguard/wgcf.conf
```

---

## Destek

1. Bu kılavuza ve [README.md](README.md) dosyasına bakın.
2. [GitHub Issues](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues) sayfasında arayın.
3. Yeni bir issue açın: macOS sürümünüzü, Mac modelinizi (Apple Silicon/Intel), uygulama sürümünü (Hakkında sekmesi) ve ekrandaki hata mesajını ekleyin.
