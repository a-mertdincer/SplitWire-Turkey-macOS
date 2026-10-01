import SwiftUI

/// ISS DNS'i Discord için engelleme adresi döndürüyorsa gösterilen uyarı (#11/#9).
/// ByeDPI ve Ağ sekmelerinin en üstünde yer alır.
struct DNSHealthBanner: View {
    /// true ise DNS doğruyken küçük yeşil bir satır gösterilir (yalnızca Ağ sekmesi).
    var showOKLine = false

    @ObservedObject private var checker = DNSHealthChecker.shared
    @ObservedObject private var network = NetworkConfigService.shared
    @State private var showDoHSheet = false

    /// Kontrol sürerken bir önceki sonucu göstermeye devam et (banner yanıp sönmesin).
    private var displayed: DNSHealthState {
        checker.isChecking ? checker.lastResult : checker.state
    }

    var body: some View {
        Group {
            switch displayed {
            case .poisoned(let systemIPs, _):
                warningBox(systemIPs: systemIPs)
            case .ok where showOKLine:
                okLine
            case .unknown where showOKLine && checker.lastChecked != nil && !checker.isChecking:
                unknownLine
            default:
                if showOKLine && checker.isChecking {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(L("DNS kontrol ediliyor...", "Checking DNS..."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        // Not: Görünüm boşken (.ok/.unknown) Group'a bağlı .task çalışmaz; ilk kontrol
        // uygulama açılışında (AppDelegate) yapılır, burada yalnızca uyarı kutusu görünürken
        // eksik bilgiler tamamlanır.
    }

    // MARK: - Parçalar

    private func warningBox(systemIPs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("DNS engellemesi algılandı", "DNS blocking detected"))
                        .font(.headline)
                    Text(blockedMessage(systemIPs: systemIPs))
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    if network.activePreset == .cloudflare {
                        Text(L("DNS zaten 1.1.1.1 olarak ayarlı ama sorun sürüyor: İnternet sağlayıcınız DNS trafiğini (53. port) yönlendiriyor olabilir. Şifreli DNS (DoH) profili bunu aşar.",
                               "DNS is already set to 1.1.1.1 but the problem persists: your ISP may be redirecting DNS traffic (port 53). The encrypted DNS (DoH) profile gets around this."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    Task { await network.apply(.cloudflare) }
                } label: {
                    Label(L("DNS'i Cloudflare (1.1.1.1) Yap", "Use Cloudflare DNS (1.1.1.1)"), systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(network.isBusy)

                Button {
                    showDoHSheet = true
                } label: {
                    Label(L("Şifreli DNS (DoH) Profili…", "Encrypted DNS (DoH) profile…"), systemImage: "lock.shield")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await checker.check() }
                } label: {
                    Label(L("Tekrar Kontrol Et", "Check again"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(checker.isChecking)

                if checker.isChecking || network.isBusy {
                    ProgressView().controlSize(.small)
                }
            }

            if !network.statusMessage.isEmpty, network.statusKind != .success {
                Text(network.statusMessage)
                    .font(.caption)
                    .foregroundColor(network.statusKind == .error ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showDoHSheet) {
            DoHProfileSheet(isPresented: $showDoHSheet)
        }
        .task {
            if !network.hasLoaded { await network.loadNetworkInfo() }
        }
        .background(Color.orange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private var okLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(L("DNS doğru çözümlüyor (discord.com gerçek adresine gidiyor)",
                   "DNS resolves correctly (discord.com points to its real address)"))
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            checkButton
        }
    }

    private var unknownLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "questionmark.circle")
                .foregroundColor(.secondary)
            Text(L("DNS durumu doğrulanamadı (şifreli DNS sunucularına ulaşılamadı).",
                   "Couldn't verify DNS status (encrypted DNS servers unreachable)."))
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            checkButton
        }
    }

    private func blockedMessage(systemIPs: [String]) -> String {
        let host = checker.affectedHost
        let ips = systemIPs.joined(separator: ", ")
        return L("DNS sunucunuz \(host) için gerçek adres yerine engelleme adresi (\(ips)) döndürüyor. ByeDPI bu durumda Discord'a bağlanamaz.",
                 "Your DNS server returns a block-page address (\(ips)) instead of the real address for \(host). ByeDPI can't connect to Discord while this happens.")
    }

    private var checkButton: some View {
        Button(L("Tekrar Kontrol Et", "Check again")) {
            Task { await checker.check() }
        }
        .controlSize(.small)
        .disabled(checker.isChecking)
    }
}

/// DoH profilini oluşturup açan ve kurulum talimatlarını gösteren sayfa.
struct DoHProfileSheet: View {
    @Binding var isPresented: Bool
    @State private var savedURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L("Şifreli DNS (DoH) Profili", "Encrypted DNS (DoH) profile"), systemImage: "lock.shield")
                .font(.title2.bold())

            Text(L("Ne zaman kullanılır?", "When should I use it?"))
                .font(.headline)
            Text(L("DNS'i 1.1.1.1 yaptıktan sonra uyarı hâlâ görünüyorsa internet sağlayıcınız DNS sorgularını (53. port) yakalayıp engelleme adresi döndürüyordur. DNS over HTTPS, sorguları Cloudflare'e şifreli (HTTPS) gönderdiği için bu müdahaleyi aşar. Profil tüm sistem için geçerlidir ve ByeDPI'ın Discord adresini doğru çözmesini sağlar.",
                   "If the warning still shows after setting DNS to 1.1.1.1, your ISP is intercepting DNS queries (port 53) and returning a block-page address. DNS over HTTPS sends queries to Cloudflare encrypted (HTTPS), which gets around this interference. The profile applies system-wide and lets ByeDPI resolve Discord's address correctly."))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Text(L("Kurulum (macOS 13 ve sonrası)", "Installation (macOS 13 and later)"))
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("1. Aşağıdaki düğmeyle profili oluşturun (İndirilenler klasörüne kaydedilir ve açılır).",
                       "1. Create the profile with the button below (it is saved to your Downloads folder and opened)."))
                Text(L("2. Sistem Ayarları > Genel > Aygıt Yönetimi bölümünü açın (macOS 13–14: Gizlilik ve Güvenlik > Profiller).",
                       "2. Open System Settings > General > Device Management (macOS 13–14: Privacy & Security > Profiles)."))
                Text(L("3. \"\(DoHProfile.displayName)\" profiline çift tıklayın ve Yükle'ye basın; parolanızı girin.",
                       "3. Double-click the \"\(DoHProfile.displayName)\" profile, click Install and enter your password."))
                Text(L("4. Uygulamaya dönüp \"Tekrar Kontrol Et\"e basın.",
                       "4. Come back to the app and click \"Check again\"."))
            }
            .font(.callout)

            Text(L("Kaldırmak için", "To remove it"))
                .font(.headline)
            Text(L("Sistem Ayarları > Genel > Aygıt Yönetimi (macOS 13–14: Gizlilik ve Güvenlik > Profiller) bölümünde profili seçip \"–\" (Kaldır) düğmesine basın.",
                   "In System Settings > General > Device Management (macOS 13–14: Privacy & Security > Profiles), select the profile and click the \"–\" (Remove) button."))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            if let savedURL {
                Label(L("Kaydedildi: \(savedURL.path)", "Saved: \(savedURL.path)"), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .textSelection(.enabled)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "xmark.octagon.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button {
                    do {
                        savedURL = try DoHProfile.saveAndOpen()
                        errorMessage = nil
                    } catch {
                        errorMessage = L("Profil kaydedilemedi: \(error.localizedDescription)",
                                         "Couldn't save the profile: \(error.localizedDescription)")
                    }
                } label: {
                    Label(L("Profili Oluştur ve Aç", "Create and open profile"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)

                Button(L("Aygıt Yönetimi'ni Aç", "Open Device Management")) {
                    DoHProfile.openProfilesSettings()
                }

                if let savedURL {
                    Button(L("Finder'da Göster", "Show in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([savedURL])
                    }
                }

                Spacer()

                Button(L("Kapat", "Close")) {
                    isPresented = false
                    DNSHealthChecker.shared.scheduleRecheck(after: 0.5)
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}
