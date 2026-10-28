# SplitWire-Turkey macOS v1.1.3

[Türkçe](#türkçe) · [English](#english)

---

## Türkçe

Bu sürüm v1.1.2'de bulunan bir hatayı düzeltiyor: ByeDPI'ın HTTPS proxy'si, macOS'un kendi ağ yığınını kullanan uygulamalarda bağlantıyı yanlış porta açıyordu.

### Ne değişti?

- **HTTPS proxy macOS uygulamalarında çalışıyor:** ByeDPI (ciadpi), HTTP CONNECT isteğinde hedef portu istek satırından değil `Host` başlığından okuyordu. macOS'un ağ yığını (URLSession, WebKit) bu başlığa port yazmadığı için bağlantı 443 yerine 80 numaralı porta gidiyor ve TLS el sıkışması kesiliyordu. SplitWire'ın derlediği ciadpi artık hedefi istek satırından (`CONNECT host:443`) alıyor; istek satırı okunamazsa eskisi gibi `Host` başlığına bakıyor.
- Bunun sonuçları:
  - ByeDPI Durumu bölümündeki **bağlantı testi**, Discord ve Roblox çalışırken bile "Hiçbir bağlantı kurulamadı" diyordu (yanlış alarm). Artık doğru sonuç veriyor.
  - **Roblox'un şifreyle girişteki güvenlik doğrulaması** ("Security" ekranı) Sistem Proxy üzerinden yükleniyor. v1.1.2'deki testimizde arada DNS çözen bir test proxy'si olduğu için bu hata görünmemişti; bu kez doğrudan ByeDPI üzerinden denendi.
  - Sistem Proxy'nin HTTPS ayarını kullanan diğer macOS uygulamaları (ör. Safari) da aynı hatadan etkilenebiliyordu.
- curl/libcurl (Roblox'un oyun istemcisi), Chromium/Electron (Discord) ve Discord'un güncelleme denetimi `Host` başlığına portu yazdığı için bu hatadan etkilenmiyordu.

### Nasıl doğrulandı?

- macOS URLSession ve WKWebView, arada başka bir proxy olmadan doğrudan ByeDPI (Split 2) üzerinden denendi. Discord, Discord'un güncelleme denetimi (TLS 1.2), Roblox'un ayar sunucusu ve Roblox'un giriş doğrulama sayfası (`www.roblox.com/challenge/cdn/hybrid`) 200 döndü. Yamasız ciadpi ile aynı istekler TLS hatası verdi.
- Yeni bir entegrasyon testi, `Host` başlığında port olmayan CONNECT isteğinin doğru porta gittiğini denetliyor; yamasız ciadpi ile başarısız oluyor.

### Yükseltme

1. v1.1.2'den çıkın (sistem proxy açıksa çıkarken kapatılır).
2. Yeni `SplitWire-Turkey.app`'i Uygulamalar klasöründeki eskisinin üzerine kopyalayın. Ayarlarınız korunur.
3. ByeDPI'ı başlatın; yeni ciadpi böylece devreye girer.

v1.1.2'deki değişiklikler için: [RELEASE_NOTES_v1.1.2.md](RELEASE_NOTES_v1.1.2.md).

---

## English

This release fixes a bug found in v1.1.2: ByeDPI's HTTPS proxy opened connections to the wrong port for apps that use macOS's own network stack.

### What changed

- **The HTTPS proxy works for macOS apps:** ByeDPI (ciadpi) read the target port of an HTTP CONNECT request from the `Host` header instead of the request line. macOS's network stack (URLSession, WebKit) doesn't put the port in that header, so the connection went to port 80 instead of 443 and the TLS handshake was cut. The ciadpi built by SplitWire now takes the target from the request line (`CONNECT host:443`) and falls back to the `Host` header only if the request line can't be read.
- What this fixes:
  - The **connection test** in the ByeDPI status section said "No connection could be made" even while Discord and Roblox worked (a false alarm). It now reports correctly.
  - **Roblox's security check when signing in with a password** (the "Security" screen) loads through System proxy. Our v1.1.2 test had a DNS-resolving test proxy in between, which hid this bug; this time it was tried directly through ByeDPI.
  - Other macOS apps that use the HTTPS part of System proxy (e.g. Safari) could be affected by the same bug.
- curl/libcurl (Roblox's game client), Chromium/Electron (Discord) and Discord's update check put the port in the `Host` header, so they weren't affected.

### How it was verified

- macOS URLSession and WKWebView were tried directly through ByeDPI (Split 2), with no other proxy in between. Discord, Discord's update check (TLS 1.2), Roblox's settings server and Roblox's sign-in security check page (`www.roblox.com/challenge/cdn/hybrid`) returned 200. With the unpatched ciadpi the same requests failed with a TLS error.
- A new integration test checks that a CONNECT request without a port in the `Host` header reaches the right port; it fails with the unpatched ciadpi.

### Upgrading

1. Quit v1.1.2 (if System proxy is on, it's turned off on quit).
2. Copy the new `SplitWire-Turkey.app` over the old one in your Applications folder. Your settings are kept.
3. Start ByeDPI; this brings the new ciadpi into use.

For the changes in v1.1.2, see [RELEASE_NOTES_v1.1.2.md](RELEASE_NOTES_v1.1.2.md).
