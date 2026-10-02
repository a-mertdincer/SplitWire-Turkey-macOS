# SplitWire-Turkey macOS v1.1.1

[Türkçe](#türkçe) · [English](#english)

---

## Türkçe

Bu sürüm [#13 "Roblox oynanmıyor"](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13) geri bildirimine yanıttır: WARP ile yalnızca tek bir sunucuya girilebiliyor, sunucu değiştirilemiyor ve WireGuard ile ping çok yüksek.

### Neler değişti?

- **Sistem Proxy artık SOCKS + HTTPS:** **Sistem Proxy > Aç**, birincil ağ servisinde hem SOCKS proxy'yi hem de güvenli web proxy'sini (HTTPS) `127.0.0.1:1080` olarak tek parola penceresiyle açar. Düz web proxy'si (HTTP) ve proxy istisna listeniz değiştirilmez.
- **ByeDPI aynı portta HTTP CONNECT kabul eder:** Tüm yöntemlere `-G` (`--http-connect`) otomatik eklenir. SOCKS5 bağlantıları etkilenmez.
- **Roblox için deneysel yol:** DNS'i düzeltin (1.1.1.1 veya DoH profili) → ByeDPI'ı başlatın → Sistem Proxy'yi açın → Roblox'u başlatın. Yalnızca Roblox'un web/giriş trafiğinin ByeDPI'dan geçmesi, oyun trafiğinin doğrudan gitmesi, dolayısıyla ping'in etkilenmemesi beklenir. Sistem proxy açıkken bu ayarı kullanan diğer uygulamalar (ör. Safari) da ByeDPI'dan geçer. İşe yaramazsa WireGuard kullanılabilir (ping daha yüksek).
- **DNS kontrolü Roblox'u da kapsar:** `www.roblox.com` bilinen engelleme adreslerine (`195.175.254.2`, `0.0.0.0`/`127.x`) ve Discord'un zehirli bulunduğu adrese karşı kontrol edilir; uyarı hangi servislerin etkilendiğini söyler ("Discord ve Roblox için…").
- Uygulama içinde kısa Roblox rehberi (ByeDPI sekmesi ve Sistem Proxy sayfası); WireGuard sekmesinde oyunlarda gecikme uyarısı.

### Neden?

Roblox, Discord'un aksine `--proxy-server` parametresini yok sayar; v1.1.0 bu yüzden yalnızca WireGuard/WARP öneriyordu ve tam tünel gecikmeyi artırıyordu. Ölçümlerde Roblox'un web/giriş adresleri Discord ile aynı şekilde engelleniyor: DNS engelleme adresi döndürüyor, doğru adresle bile doğrudan TLS bağlantısı DPI'a takılıyor; ByeDPI üzerinden ise tüm yöntemlerle erişilebiliyor. HTTPS proxy, macOS ağ ayarlarını kullanan uygulamaların ByeDPI'a ulaşabileceği ikinci bir yol sunar.

### Güncelleme notları

- Tüm ayarlarınız korunur (yöntem, özel parametreler, favori uygulamalar, dil).
- v1.1.0'da Sistem Proxy açtıysanız (yalnızca SOCKS), bu ayar da algılanır ve ByeDPI durunca veya çıkışta otomatik kapatılır. HTTPS proxy'yi de almak için ByeDPI çalışırken **Sistem Proxy > Aç**'a yeniden basın (başka ağ servislerinde kalmış yarım ayarlar da aynı parola penceresinde tamamlanır).
- Birincil serviste başka bir sunucuyu gösteren kendi SOCKS veya HTTPS proxy'niz (ör. şirket proxy'si) açıksa sistem proxy onun üzerine yazılmaz; uygulama nedenini söyler.
- v1.1.0'dan kalma, arka planda çalışan bir ByeDPI varsa sistem proxy açılmadan önce durdurup yeniden başlatmanız istenir (eski süreç HTTPS proxy'yi desteklemez).

### Dürüst bir not

Roblox'un sistem proxy ayarlarını kullanıp kullanmadığını henüz doğrulayamadık; bu yüzden yol **deneysel**. Denediyseniz, işe yarasa da yaramasa da lütfen [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13) üzerinden bildirin.

---

## English

This release responds to the feedback on [#13 "Roblox oynanmıyor" (Roblox doesn't work)](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13): with WARP you can only join one server and can't switch servers, and with WireGuard the ping is very high.

### What changed?

- **System proxy is now SOCKS + HTTPS:** **System proxy > Turn on** sets both the SOCKS proxy and the secure web proxy (HTTPS) of the primary network service to `127.0.0.1:1080`, with a single password prompt. The plain web proxy (HTTP) and your proxy bypass list are not changed.
- **ByeDPI accepts HTTP CONNECT on the same port:** `-G` (`--http-connect`) is added to every method automatically. SOCKS5 connections are not affected.
- **Experimental route for Roblox:** fix DNS (1.1.1.1 or the DoH profile) → start ByeDPI → turn on System proxy → start Roblox. Only Roblox's web/login traffic is expected to go through ByeDPI; game traffic is expected to go direct, so ping should stay about the same. While the system proxy is on, other apps that use it (such as Safari) also go through ByeDPI. If it doesn't work, WireGuard is still available (higher ping).
- **The DNS check covers Roblox too:** `www.roblox.com` is checked against known block addresses (`195.175.254.2`, `0.0.0.0`/`127.x`) and the address Discord was found poisoned with, and the banner says which services are affected ("For Discord and Roblox, …").
- A short Roblox guide in the app (ByeDPI tab and System proxy sheet), and a latency note for games in the WireGuard tab.

### Why?

Unlike Discord, Roblox ignores the `--proxy-server` flag, so v1.1.0 only offered WireGuard/WARP, and the full tunnel adds latency. Measurements show Roblox's web/login hosts are blocked the same way as Discord: DNS returns the block address, and even with the correct address a direct TLS connection is cut by DPI; through ByeDPI they are reachable with every method. The HTTPS proxy gives apps that use the macOS network settings a second way to reach ByeDPI.

### Upgrade notes

- All your settings are kept (method, custom arguments, favorite apps, language).
- If you turned on System proxy in v1.1.0 (SOCKS only), it is detected too and turned off automatically when ByeDPI stops or you quit. To also get the HTTPS proxy, press **System proxy > Turn on** again while ByeDPI is running (partial settings left on other network services are completed in the same password prompt).
- If your own SOCKS or HTTPS proxy pointing to another server (e.g. a company proxy) is on for the primary service, the system proxy won't overwrite it; the app tells you why.
- If a ByeDPI left over from v1.1.0 is still running in the background, you are asked to stop and restart it before the system proxy is turned on (the old process doesn't support the HTTPS proxy).

### An honest note

We haven't been able to verify yet whether Roblox uses the macOS system proxy settings, so this route is **experimental**. If you try it, please report on [#13](https://github.com/a-mertdincer/SplitWire-Turkey-macOS/issues/13) whether it works or not.
