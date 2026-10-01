# SplitWire-Turkey macOS - Kullanım Kılavuzu

Bu kılavuz v1.1.0 içindir. Kısa özet ve İngilizce açıklama için [README.md](README.md), sürüm notları için [RELEASE_NOTES_v1.1.0.md](RELEASE_NOTES_v1.1.0.md) dosyasına bakın.

İçindekiler:

1. [Kurulum](#kurulum)
2. [Arayüz](#arayüz)
3. [Discord için hızlı başlangıç](#discord-için-hızlı-başlangıç)
4. [ByeDPI](#byedpi)
5. [Sistem Proxy](#sistem-proxy)
6. [DNS ayarları](#dns-ayarları)
7. [Şifreli DNS (DoH) profili](#şifreli-dns-doh-profili)
8. [WireGuard / Cloudflare WARP](#wireguard--cloudflare-warp)
9. [Dock simgesi, dil ve koyu mod](#dock-simgesi-dil-ve-koyu-mod)
10. [Sorun giderme](#sorun-giderme)
11. [v1.0.0'dan güncelleme](#v100dan-güncelleme)
12. [Tamamen kaldırma](#tamamen-kaldırma)

---

## Kurulum

Gereksinimler: macOS 13 veya üstü, Apple Silicon veya Intel Mac.

1. [Releases](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/releases) sayfasından `SplitWire-Turkey-v1.1.0.zip` dosyasını indirin ve çift tıklayarak açın.
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
shasum -a 256 -c SplitWire-Turkey-v1.1.0.zip.sha256
```

---

## Arayüz

**Pencerenin üst kısmı:** Dil seçici (Türkçe / English), **Dock simgesini gizle** onay kutusu ve koyu mod anahtarı.

**Sekmeler:**

| Sekme | İçerik |
|---|---|
| WireGuard | Cloudflare WARP tüneli: kurulum, açılışta otomatik bağlanma seçeneği, bağlan/bağlantıyı kes, kaldırma |
| ByeDPI (açılışta seçili) | DNS uyarısı, ByeDPI durumu, Hızlı İşlemler, DPI yöntemleri, Discord ayarları |
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
3. **Hızlı İşlemler** bölümündeki **Discord** simgesine tıklayın.
   - Discord açıksa **Kapat ve Yeniden Başlat**'ı seçin. 8 saniye içinde kapanmazsa zorla kapatmak isteyip istemediğiniz sorulur.
   - Discord'u her seferinde buradan başlatın. Dock veya Spotlight'tan açılan Discord proxy kullanmaz.
4. Hâlâ bağlanmıyorsa **Önceden Hazır Ayarlar** bölümünden başka bir yöntem seçin.

> İpucu: Discord sürekli "update failed" diyorsa **Gelişmiş > Discord Ayarları** bölümündeki satırları Discord'un `settings.json` dosyasına ekleyerek otomatik güncellemeleri kapatabilirsiniz. **settings.json Klasörünü Aç** düğmesi dosyayı Finder'da gösterir.

---

## ByeDPI

ByeDPI (ciadpi), bu Mac'te `127.0.0.1:1080` adresinde dinleyen bir SOCKS5 proxy'dir. Yalnızca bu bilgisayardan erişilebilir. Yönetici yetkisi gerektirmez.

### Başlatma ve durdurma

- **Başlat / Durdur:** ByeDPI sekmesi > Hızlı İşlemler veya menü çubuğu.
- **Tümünü Zorla Kapat:** Kendi başlattığınız ya da önceki oturumdan kalmış tüm ciadpi süreçlerini sonlandırır. Gerekirse yönetici parolası ister ve açıksa sistem proxy'yi de aynı pencerede kapatır.
- ByeDPI beklenmedik şekilde durursa durum mesajında ciadpi'nin hata çıktısı görünür.
- Önceki bir oturumdan kalmış bir ciadpi çalışıyorsa durum **Çalışıyor (harici süreç)** olarak görünür. Seçili yöntemi uygulamak için durdurup yeniden başlatın.
- v1.0.0'dan kalma bir ciadpi tüm ağ arayüzlerinde dinliyorsa (aynı ağdaki herkes proxy'yi kullanabilir) ByeDPI sekmesinde kırmızı, menü çubuğunda turuncu uyarı görünür ve uygulama **Güvenli Yeniden Başlat** ile yalnızca `127.0.0.1`'de yeniden başlatmayı önerir. Süreç başka bir kullanıcıya aitse **Tümünü Zorla Kapat**'ı kullanın.

### DPI yöntemi seçme

**Önceden Hazır Ayarlar** bölümündeki listeden veya menü çubuğu > **DPI Yöntemi**'nden seçin. Seçim kaydedilir ve uygulama yeniden açıldığında korunur. ByeDPI çalışıyorsa yeni yöntemle otomatik yeniden başlar. Yeni yöntem başlatılamazsa ByeDPI önceki yöntemle yeniden açılır; o da olmazsa sistem proxy kapatılır (internetiniz kesilmesin diye).

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
| Özel | Kendi parametreleriniz |

Fake yöntemleri kaldırıldı: macOS'taki ciadpi sahte paket gönderemez.

Önerilen deneme sırası: önce **Standart**; olmazsa **Disorder**, **Split + Disorder**, **Disorder SNI**, **Split 2**, **OOB**. Bir site açılmıyorsa önce DNS uyarısını kontrol edin; sorun çoğu zaman DNS'tir.

### Özel (Custom) parametreler

1. **Özel Parametreleri Düzenle**'ye basın: Özel moda geçilir. Kaydettiğiniz özel parametreler korunur; metin kutusu yalnızca boşsa veya hazır yöntemlerden biriyle aynıysa seçili yöntemin parametreleriyle doldurulur.
2. Metin kutusuna ciadpi parametrelerini yazın (ör. `-s 1 --tlsrec 1+s`). Birden çok satır ve tırnaklı değerler desteklenir.
3. **Uygula**'ya basın. ByeDPI çalışıyorsa bu parametrelerle yeniden başlar. Parametreler boşsa ByeDPI önceki yöntemle çalışmaya devam eder.

`-i 127.0.0.1` ve `-p 1080` otomatik eklenir. Bunları kendiniz yazarsanız sizinki kullanılır; değiştirmeniz önerilmez (uygulamanın geri kalanı 127.0.0.1:1080 varsayar). Parametreler kaydedilir.

### Hızlı İşlemler (uygulama başlatma)

- **Uygulama ekle:** Hızlı İşlemler başlığındaki **+** > **Applications Klasöründen Seç**.
- **Başlat:** Uygulama simgesine tıklayın. ByeDPI kapalıysa önce otomatik başlatılır, ardından uygulama proxy parametresiyle açılır.
- **Düzenle / Kaldır:** Simgenin üzerine gelince çıkan kalem ve çarpı düğmeleri. Varsayılan başlatma parametresi `--proxy-server=socks5://127.0.0.1:1080`'dir; **Varsayılana Sıfırla** ile geri dönebilirsiniz.

Proxy parametresi yalnızca Chromium/Electron tabanlı uygulamalarda çalışır (Discord, Chrome, Brave, Edge, Slack, Spotify…). Safari için [Sistem Proxy](#sistem-proxy)'yi, Roblox ve oyunlar için [WireGuard](#wireguard--cloudflare-warp)'ı kullanın.

---

## Sistem Proxy

Proxy parametresini desteklemeyen uygulamalar (ör. Safari) için sistem genelinde SOCKS proxy ayarı.

1. ByeDPI'ı başlatın.
2. **Hızlı İşlemler > Sistem Proxy > Aç** ve yönetici parolanızı girin. Proxy, birincil ağ servisinizde (ör. Wi-Fi) `127.0.0.1:1080` olarak açılır.
3. Kapatmak için aynı pencerede **Kapat** veya menü çubuğu > **Sistem Proxy'yi Kapat**.

Önemli:

- Sistem proxy yalnızca ByeDPI çalışırken güvenlidir. ByeDPI kapalıyken açık kalırsa **internet çalışmaz**.
- Proxy açılırken yönetici komutu ByeDPI'ın hâlâ dinlediğini kontrol eder; parola penceresi açıkken ByeDPI durduysa proxy açılmaz.
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

Uygulama açılışta `discord.com` ve `gateway.discord.gg` adlarını hem sistem DNS'i ile hem de şifreli DNS (Cloudflare/Google DoH) ile çözer ve sonuçları karşılaştırır. Sistem DNS'i engelleme sayfası adresi (ör. `195.175.254.2`) veya ilgisiz bir adres döndürüyorsa ByeDPI ve Ağ Ayarları sekmelerinin üstünde turuncu uyarı görünür.

Neden önemli: ciadpi bağlanacağı adresi sistem DNS'i ile bulur. DNS engelleme adresi döndürüyorsa DPI aşılsa bile Discord'a bağlanılamaz.

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

Bu mod Mac'in **tüm** internet trafiğini ve DNS sorgularını ücretsiz Cloudflare WARP üzerinden geçirir. ByeDPI ile çalışmayan uygulamalar (Roblox, oyunlar vb.) için kullanışlıdır. macOS'ta uygulama bazlı bölünmüş tünel (yalnızca Discord gibi) desteklenmez.

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

### Discord bağlanmıyor / "update failed"

1. DNS uyarısını kontrol edin ve [DNS ayarları](#dns-ayarları) adımlarını uygulayın.
2. Discord'u SplitWire'daki Hızlı İşlemler'den **yeniden başlatın**.
3. Başka bir DPI yöntemi deneyin.
4. Hâlâ olmuyorsa [WireGuard](#wireguard--cloudflare-warp) modunu deneyin.

Terminal'den test (ByeDPI çalışırken):

```bash
curl -I --socks5-hostname 127.0.0.1:1080 https://discord.com
```

`HTTP/2 200` (veya benzeri bir HTTP yanıtı) görürseniz proxy ve DNS çalışıyordur.

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
2. Elle: **Sistem Ayarları > Ağ** > bağlı olduğunuz servis (Wi-Fi veya Ethernet) > **Ayrıntılar…** > **Proxy'ler** > **SOCKS proxy**'yi kapatın > **Tamam**.
3. Terminal ile:
   ```bash
   networksetup -listallnetworkservices                       # servis adlarını listeler
   networksetup -getsocksfirewallproxy "Wi-Fi"                # durumu gösterir
   sudo networksetup -setsocksfirewallproxystate "Wi-Fi" off  # kapatır
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

## v1.0.0'dan güncelleme

1. v1.0.0'dan çıkın (menü çubuğu > Çıkış veya ⌘Q).
2. Yeni `SplitWire-Turkey.app`'i Uygulamalar klasöründeki eskisinin üzerine kopyalayın ve [ilk açılış](#gatekeeper-uyarısı-ilk-açılış) adımlarını uygulayın.

Ayarlarınız korunur: favori uygulamalar, koyu mod, dil ve menü çubuğunda seçtiğiniz DPI yöntemi taşınır. Kaldırılan Fake yöntemlerinden birini seçtiyseniz Standart'a dönülür. v1.0.0'ın işe yaramayan WireGuard klasör/tarayıcı ayarları silinir.

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
