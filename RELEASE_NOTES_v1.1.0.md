# SplitWire-Turkey macOS v1.1.0

[Türkçe](#türkçe) · [English](#english)

---

## Türkçe

### Öne çıkanlar

- **Discord için DNS kontrolü:** Uygulama, operatör DNS'inin `discord.com` için engelleme adresi döndürüp döndürmediğini kontrol eder ve tek tıkla Cloudflare DNS (1.1.1.1) veya şifreli DNS (DoH) profili önerir.
- **Intel Mac desteği:** Uygulama ve ByeDPI artık evrensel (Apple Silicon + Intel), macOS 13 ve üstünde çalışır.
- **"Hasar görmüş" hatası yok:** Paket artık düzgün imzalanıyor.
- **WireGuard / Cloudflare WARP kurulumu çalışıyor.**
- **Türkçe / English arayüz**, **Dock simgesini gizleme**.
- **İnternetinizi bozmayan sistem proxy:** ByeDPI durunca veya uygulamadan çıkınca otomatik kapanır.
- **Pencere ve menü çubuğu artık aynı şeyi gösterir;** seçtiğiniz yöntem kaydedilir.

### Düzeltilen sorunlar

| Issue | Ne değişti? |
|---|---|
| #4 WireGuard kurulumu başarısız | wgcf artık GitHub'dan bu Mac'e uygun sürümüyle indiriliyor ve doğrulanıyor (v1.0.0 "Not Found" sayfasını program diye kaydediyordu). Homebrew'daki wgcf de kullanılabiliyor. Parola tek bir macOS penceresinde soruluyor, wg-quick Apple Silicon ve Intel Homebrew'da doğru bulunuyor. Açılışta otomatik bağlanma isteğe bağlı ve varsayılan olarak kapalı (güvenlik uyarısıyla). Gereksinim: `brew install wireguard-tools`. |
| #6 Dock'tan gizleme | Pencerenin üstünde ve menü çubuğunda **Dock simgesini gizle** seçeneği. Pencere kapatılınca uygulama menü çubuğunda çalışmaya devam eder. |
| #7 Yanlış yönetici uyarısı | Açılıştaki "Yönetici Yetkileri Gerekli" uyarısı kaldırıldı. Parola yalnızca sistem ayarı değişirken (DNS, sistem proxy, WireGuard; gerekirse "Tümünü Zorla Kapat") standart macOS penceresiyle isteniyor. |
| #8 Dil seçimi çalışmıyordu | Gerçek Türkçe/İngilizce arayüz; değişiklik pencereye ve menü çubuğuna anında, macOS'un kendi menülerine (Gizle, Çık, Düzen, Pencere) bir sonraki açılışta uygulanır. Çevirisi olmayan Rusça seçeneği kaldırıldı. |
| #10 Intel Mac uyumsuzluğu | Uygulama ve ciadpi evrensel (arm64 + x86_64) derleniyor. |
| #11 / #9 Discord çalışmıyor | Asıl neden DNS: operatör DNS'i `discord.com` için engelleme adresi (`195.175.254.2`) döndürüyor ve ciadpi adresi sistem DNS'i ile çözüyor. Uygulama bunu algılayıp uyarıyor. "DNS'i ayarla" düğmesi artık gerçekten çalışıyor (v1.0.0 servis adı yerine `en0` gönderiyordu). DoH profili, 53. portu yakalayan operatörler için. Discord açıksa "Kapat ve Yeniden Başlat" öneriliyor; proxy ayarı ancak böyle uygulanıyor. |
| #12 Yöntem kaydedilmiyordu | Pencere ve menü çubuğu tek bir ByeDPI servisini paylaşıyor. Seçim kaydediliyor ve geri yükleniyor; çalışan yöntem ve tam parametreler gösteriliyor. |
| #13 Roblox açılmıyor | Belgelenmiş kısıt: Roblox (ve oyunlar) proxy parametresini kullanmaz. Alternatif: artık çalışan **WireGuard/WARP** modu. |
| #14 İnternet bağlantısı koptu | Sistem proxy ByeDPI durunca, "Tümünü Zorla Kapat"ta ve çıkışta otomatik kapanıyor. Çıkışta kapatılamazsa uygulama sessizce çıkmak yerine soruyor. ByeDPI çökerse veya açılışta proxy açık kalmışsa uygulama uyarıyor. |
| #2 / #5 "Hasar görmüş" hatası | Paket içten dışa ad-hoc imzalanıyor ve her derlemede doğrulanıyor. |

### Diğer düzeltmeler

- **Fake yöntemleri kaldırıldı:** macOS'taki ciadpi sahte paket gönderemez, bu yöntemler hiç çalışmıyordu. Yeni yöntemler: **Disorder SNI**, **OOB SNI**. **Split + Disorder** parametreleri güncellendi.
- **ByeDPI yalnızca bu Mac'e açık:** Proxy `127.0.0.1`'de dinliyor (v1.0.0'da `0.0.0.0`, yani yerel ağdaki herkese açıktı).
- **Özel (Custom) parametreler çalışıyor** (v1.0.0'da yok sayılıyordu); çok satırlı ve tırnaklı değerler destekleniyor. "Özel Parametreleri Düzenle" kaydettiğiniz özel parametreleri korur; yalnızca boşsa veya bir hazır yöntemle aynıysa seçili yöntemin parametreleriyle doldurur.
- **ByeDPI güvenilir şekilde duruyor:** ciadpi normal kapatma sinyalini yok saydığı için zorla sonlandırılıyor. Önceki oturumdan kalan süreçler algılanıyor ve durdurulabiliyor.
- **Ağa açık eski ByeDPI algılanıyor:** v1.0.0'dan kalma, tüm ağ arayüzlerinde dinleyen bir ciadpi kalıcı bir uyarıyla gösteriliyor ve uygulama onu yalnızca `127.0.0.1`'de güvenli şekilde yeniden başlatmayı öneriyor.
- **Yöntem değişikliği interneti bozmuyor:** Yeni yöntem başlatılamazsa ByeDPI önceki yöntemle yeniden açılıyor; o da olmazsa sistem proxy kapatılıyor. Boş Özel parametreler çalışan ByeDPI'ı durdurmuyor.
- **Sistem proxy yalnızca ByeDPI dinlerken açılıyor:** Yönetici komutu ciadpi'nin hâlâ dinlediğini kontrol ediyor; parola penceresi açıkken ByeDPI durduysa proxy açılmıyor.
- **Parola pencereleri nedenini söylüyor:** Her yönetici parolası penceresi hangi işlem için istendiğini yazıyor.
- **wgcf indirmesi SHA-256 ile doğrulanıyor:** Önce özeti uygulamaya gömülü v2.3.0 indiriliyor; özeti bilinmeyen dosya kabul edilmiyor. WARP sunucu adresi kurulumda şifreli DNS (DoH) ile çözülüp IP olarak yazılıyor.
- **DNS hataları gösteriliyor:** `networksetup` DNS'i değiştiremezse hata metni artık görünüyor (önceden başarılı sanılabiliyordu).
- **Arayüz donmuyor:** Tüm komutlar arka planda ve zaman aşımıyla çalışıyor.
- **Daha güvenli komutlar:** Kabuk enjeksiyonu riskleri giderildi; komutlar argüman dizisiyle çalıştırılıyor, yönetici komutları kaçırılıyor.
- **macOS 13+ desteği:** v1.0.0'daki ciadpi yalnızca Apple Silicon ve **macOS 15+** için derlenmişti (macOS 13–14'te ByeDPI başlamıyordu). Artık macOS 13+ ve evrensel.
- **Daha anlaşılır hatalar:** ciadpi'nin kendi hata çıktısı gösteriliyor; 1080 portunu başka bir program kullanıyorsa adı ve PID'si yazıyor.
- **WireGuard modu dürüst:** macOS uygulama bazlı tüneli desteklemediği için işe yaramayan klasör/tarayıcı seçenekleri kaldırıldı; arayüz tüm trafiğin WARP'tan geçtiğini açıkça söylüyor.
- Ana pencere kapatılsa ve Dock simgesi gizli olsa bile menü çubuğundan geri açılabiliyor.
- **Hakkında** sürümün yanında derleme numarasını ve commit'i gösteriyor (hata bildirimlerine ekleyin).

### Güncelleme notları

- **Ayarlarınız korunur:** Favori uygulamalar, koyu mod, dil ve menü çubuğunda seçtiğiniz yöntem taşınır. Kaldırılan bir Fake yöntemi seçiliyse Standart'a dönülür.
- **Sistem proxy otomatik kapanır:** ByeDPI'ı durdurduğunuzda veya çıkışta parola istenir. Durdururken iptal ederseniz proxy açık kalır ve uygulama uyarır (Sistem Proxy > Kapat ile kapatın). Çıkışta kapatılamazsa uygulama **Tekrar Dene** / **ByeDPI çalışsın, çık** / **Çıkma** seçeneklerini sunar.
- **İlk açılış (Gatekeeper):** Uygulama ad-hoc imzalı. macOS 13–14'te sağ tık > Aç; macOS 15+'ta Sistem Ayarları > Gizlilik ve Güvenlik > **Yine de Aç**. Ya da: `xattr -dr com.apple.quarantine /Applications/SplitWire-Turkey.app`
- **Evrensel paket:** Aynı zip Apple Silicon ve Intel Mac'lerde çalışır.
- v1.0.0'da WireGuard'ı denediyseniz `brew install wireguard-tools` sonrası **Kur ve Bağlan**'a basmanız yeterli; bozuk wgcf dosyası otomatik değiştirilir. v1.0.0'ın kurduğu açılışta başlatma, **Açılışta otomatik bağlan** seçili değilse kaldırılır.

### Bilinen kısıtlar

- WireGuard modu Homebrew `wireguard-tools` paketini gerektirir ve **tüm** trafiği Cloudflare WARP'tan geçirir (macOS'ta uygulama bazlı tünel yok).
- WireGuard açılışta varsayılan olarak otomatik bağlanmaz; bilgisayar yeniden başladıktan sonra **Bağlan**'a basmanız (ve parola girmeniz) gerekir. **Açılışta otomatik bağlan** seçeneği bunu kaldırır, ancak Homebrew'un kullanıcı hesabınızca değiştirilebilen `wg-quick`, `bash`, `wg` ve `wireguard-go` programlarını her açılışta root olarak çalıştırır; bu yüzden varsayılan olarak kapalıdır. Açılışta başlatma tek sefer dener, başarısız olursa yeniden denemez.
- macOS'un kendi menüleri uygulama içi dil değişikliğine ancak uygulama yeniden açılınca uyar.
- DoH profilini uygulama yüklemez; Sistem Ayarları'ndan sizin yüklemeniz gerekir.
- Roblox, Safari ve oyunlar uygulama bazlı proxy parametresini yok sayar. Safari için Sistem Proxy'yi, Roblox ve oyunlar için WireGuard'ı kullanın.
- Uygulama Apple tarafından notarize edilmemiştir; ilk açılışta Gatekeeper onayı gerekir.

---

## English

### Highlights

- **DNS check for Discord:** The app checks whether your ISP's DNS returns a block address for `discord.com` and offers one-click Cloudflare DNS (1.1.1.1) or an encrypted DNS (DoH) profile.
- **Intel Mac support:** The app and ByeDPI are now universal (Apple Silicon + Intel) and run on macOS 13 and later.
- **No more "damaged" error:** The bundle is now signed properly.
- **WireGuard / Cloudflare WARP setup works.**
- **Turkish / English interface**, **hide the Dock icon**.
- **A system proxy that doesn't break your internet:** it turns off automatically when ByeDPI stops or you quit.
- **The window and the menu bar now agree;** your chosen method is saved.

### Fixed issues

| Issue | What changed |
|---|---|
| #4 WireGuard setup failed | wgcf is now downloaded from GitHub in the right build for your Mac and verified (v1.0.0 saved a "Not Found" page as the program). An existing Homebrew wgcf is used too. The password is asked once in a macOS dialog, and wg-quick is found on both Apple Silicon and Intel Homebrew. Connecting automatically at startup is optional and off by default (with a security warning). Requirement: `brew install wireguard-tools`. |
| #6 Hide from Dock | **Hide Dock icon** option at the top of the window and in the menu bar. Closing the window keeps the app running in the menu bar. |
| #7 Wrong admin prompt | The "Administrator privileges required" alert at launch is gone. Your password is only asked, in the standard macOS dialog, when a system setting changes (DNS, system proxy, WireGuard; "Force stop all" if needed). |
| #8 Language picker did nothing | Real Turkish/English interface; switching applies to the window and menu bar immediately, and to macOS's own menus (Hide, Quit, Edit, Window) the next time the app starts. The untranslated Russian option was removed. |
| #10 Intel Mac incompatibility | The app and ciadpi are built universal (arm64 + x86_64). |
| #11 / #9 Discord not working | Root cause is DNS: the ISP's DNS returns a block address (`195.175.254.2`) for `discord.com`, and ciadpi resolves hosts with the system DNS. The app now detects and warns about this. The "set DNS" button actually works now (v1.0.0 passed `en0` instead of the network service name). The DoH profile covers ISPs that intercept port 53. If Discord is already running, the app offers "Quit and relaunch", which is the only way the proxy setting applies. |
| #12 Method not remembered | The window and menu bar share one ByeDPI service. The choice is saved and restored; the active method and exact arguments are shown. |
| #13 Roblox won't open | Documented limitation: Roblox (and games) ignore the proxy flag. Alternative: the now-working **WireGuard/WARP** mode. |
| #14 Internet connection lost | The system proxy turns off automatically when ByeDPI stops, on "Force stop all" and on quit. If it can't be turned off at quit, the app asks instead of quitting silently. The app warns you if ByeDPI crashes or if the proxy was left on at launch. |
| #2 / #5 "App is damaged" error | The bundle is signed ad-hoc inside-out and verified on every build. |

### Other fixes

- **Fake presets removed:** ciadpi on macOS can't send fake packets, so these presets never worked. New presets: **Disorder SNI**, **OOB SNI**. **Split + Disorder** arguments updated.
- **ByeDPI is reachable from this Mac only:** the proxy listens on `127.0.0.1` (v1.0.0 used `0.0.0.0`, i.e. open to everyone on your local network).
- **Custom arguments work** (v1.0.0 ignored them); multi-line and quoted values are supported. "Edit custom parameters" keeps your saved custom arguments; it only fills in the selected method's arguments when they are empty or identical to a built-in method.
- **ByeDPI stops reliably:** ciadpi ignores the normal termination signal, so it is force-killed. Processes left over from a previous session are detected and can be stopped.
- **An exposed old ByeDPI is detected:** a ciadpi left over from v1.0.0 that listens on all network interfaces is shown with a persistent warning, and the app offers to restart it safely on `127.0.0.1` only.
- **Changing methods doesn't break your internet:** if the new method can't start, ByeDPI goes back to the previous one; if that fails too, the system proxy is turned off. Empty Custom arguments no longer stop a running ByeDPI.
- **The system proxy is only turned on while ByeDPI is listening:** the admin command checks that ciadpi is still listening; if ByeDPI stopped while the password prompt was open, the proxy is not turned on.
- **Password prompts say why:** every administrator password dialog states what it is for.
- **wgcf download is SHA-256 verified:** the v2.3.0 build whose digest is embedded in the app is tried first; a file without a known digest is never accepted. During setup the WARP server address is resolved over encrypted DNS (DoH) and written as an IP address.
- **DNS errors are shown:** if `networksetup` can't change DNS, its error text is now shown (it could look like a success before).
- **No UI freezes:** all commands run in the background with timeouts.
- **Safer commands:** shell injection risks fixed; commands run as argument arrays and admin commands are escaped.
- **macOS 13+ support:** v1.0.0's ciadpi was built for Apple Silicon and **macOS 15+** only (ByeDPI couldn't start on macOS 13–14). It is now macOS 13+ and universal.
- **Clearer errors:** ciadpi's own error output is shown; if another program uses port 1080, its name and PID are shown.
- **Honest WireGuard mode:** the folder/browser options that couldn't work (macOS has no per-app tunnelling) were removed; the UI states clearly that all traffic goes through WARP.
- The main window can be reopened from the menu bar even after it was closed and with the Dock icon hidden.
- **About** shows the build number and commit next to the version (include it in bug reports).

### Upgrade notes

- **Your settings are kept:** favorite apps, dark mode, language and the method you chose in the menu bar carry over. A removed Fake preset falls back to Standard.
- **The system proxy turns off automatically:** you are asked for your password when you stop ByeDPI or quit. If you cancel while stopping, the proxy stays on and the app warns you (turn it off with System proxy > Turn off). If it can't be turned off at quit, the app offers **Try again** / **Quit, keep ByeDPI running** / **Don't quit**.
- **First launch (Gatekeeper):** the app is signed ad-hoc. On macOS 13–14, right-click > Open; on macOS 15+, System Settings > Privacy & Security > **Open Anyway**. Or: `xattr -dr com.apple.quarantine /Applications/SplitWire-Turkey.app`
- **Universal package:** the same zip works on Apple Silicon and Intel Macs.
- If you tried WireGuard on v1.0.0, run `brew install wireguard-tools` and click **Install and connect**; the broken wgcf file is replaced automatically. The start-at-boot daemon installed by v1.0.0 is removed unless **Connect automatically at startup** is selected.

### Known limitations

- WireGuard mode requires Homebrew `wireguard-tools` and sends **all** traffic through Cloudflare WARP (no per-app tunnelling on macOS).
- By default WireGuard does not connect at startup; after a restart you click **Connect** (and enter your password). **Connect automatically at startup** removes that step, but it runs Homebrew's `wg-quick`, `bash`, `wg` and `wireguard-go`, which your user account can modify, as root at every boot, so it is off by default. Start at boot tries once and doesn't retry if it fails.
- macOS's own menus only follow an in-app language change after the app is restarted.
- The app doesn't install the DoH profile for you; you install it in System Settings.
- Roblox, Safari and games ignore the per-app proxy flag. Use System proxy for Safari and WireGuard for Roblox and games.
- The app is not notarized by Apple; Gatekeeper approval is needed on first launch.
