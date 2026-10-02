import SwiftUI

struct WireGuardView: View {
    // Uygulama düzeyindeki paylaşılan örnek: dil değişince pencere yeniden kurulsa da
    // süren kurulum/bağlantı işlemi ve durum kaybolmaz (#8).
    @ObservedObject private var wireGuardService = WireGuardService.shared
    /// Açılışta otomatik bağlanma (LaunchDaemon) — güvenlik nedeniyle varsayılan kapalı.
    @AppStorage("wireGuardStartAtBoot") private var startAtBoot = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusSection
                prerequisitesSection
                actionsSection
                infoSection
            }
            .padding()
        }
        .task {
            await wireGuardService.refreshStatus()
        }
    }

    // MARK: - Durum

    private var statusSection: some View {
        GroupBox(label: Label(L("Cloudflare WARP (WireGuard) Durumu", "Cloudflare WARP (WireGuard) status"), systemImage: "network.badge.shield.half.filled")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L("Durum:", "Status:"))
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: stateIcon)
                        .foregroundColor(stateColor)
                    Text(wireGuardService.connectionState.title)
                        .foregroundColor(stateColor)
                    Button {
                        Task { await wireGuardService.refreshStatus() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help(L("Durumu yenile", "Refresh status"))
                    .disabled(wireGuardService.isProcessing)
                }

                if case .connected(let interface) = wireGuardService.connectionState {
                    row(L("Arayüz:", "Interface:"), interface)
                }

                if wireGuardService.isConfigured {
                    row(L("Otomatik başlatma:", "Start at boot:"),
                        wireGuardService.isLaunchDaemonInstalled
                            ? L("Açılışta otomatik bağlanır", "Connects automatically at startup")
                            : L("Kurulu değil", "Not installed"))
                }

                if !wireGuardService.statusMessage.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: messageIcon)
                            .foregroundColor(messageColor)
                        Text(wireGuardService.statusMessage)
                            .font(.caption)
                            .foregroundColor(messageColor)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if wireGuardService.isProcessing {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }
            .padding()
        }
    }

    // MARK: - Önkoşullar

    private var prerequisitesSection: some View {
        GroupBox(label: Label(L("Gereksinimler", "Requirements"), systemImage: "checklist")) {
            VStack(alignment: .leading, spacing: 8) {
                prerequisiteRow(
                    ok: wireGuardService.prerequisitesMet,
                    title: L("WireGuard araçları (wg-quick)", "WireGuard tools (wg-quick)"),
                    detail: wgQuickDetail
                )
                prerequisiteRow(
                    ok: wireGuardService.wgcfPath != nil,
                    title: "wgcf",
                    detail: wgcfDetail,
                    missingIsWarning: false
                )

                if !wireGuardService.prerequisitesMet {
                    Text(L("WireGuard araçlarını kurmak için Terminal'de şu komutu çalıştırın:",
                           "To install the WireGuard tools, run this command in Terminal:"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text(WireGuardSupport.installCommandHint)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                        Button(L("Komutu Kopyala", "Copy command")) {
                            wireGuardService.copyInstallCommand()
                        }
                        if wireGuardService.brewPath == nil {
                            Button(L("brew.sh'i Aç", "Open brew.sh")) {
                                wireGuardService.openHomebrewSite()
                            }
                        }
                    }
                    if wireGuardService.brewPath == nil {
                        Text(L("Homebrew kurulu görünmüyor; önce brew.sh adresindeki talimatlarla Homebrew'u kurun.",
                               "Homebrew doesn't appear to be installed; install it first by following the instructions at brew.sh."))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var wgQuickDetail: String {
        if let path = wireGuardService.wgQuickPath {
            if wireGuardService.missingCompanionTools.isEmpty {
                return path
            }
            let list = wireGuardService.missingCompanionTools.joined(separator: ", ")
            return L("Eksik: \(list)", "Missing: \(list)")
        }
        return L("Bulunamadı", "Not found")
    }

    private var wgcfDetail: String {
        if let path = wireGuardService.wgcfPath {
            return path
        }
        if wireGuardService.hasInvalidWgcf {
            return L("Bozuk dosya bulundu; kurulumda yeniden indirilecek",
                     "Broken file found; it will be downloaded again during setup")
        }
        return L("Kurulumda otomatik indirilecek", "Will be downloaded automatically during setup")
    }

    // MARK: - İşlemler

    private var actionsSection: some View {
        GroupBox(label: Label(L("İşlemler", "Actions"), systemImage: "gearshape.2")) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(wireGuardService.isConfigured ? L("Yeniden Kur", "Reinstall") : L("Kurulum", "Setup"))
                        .font(.headline)
                    Text(L("wgcf ile ücretsiz bir Cloudflare WARP hesabı ve WireGuard profili oluşturur, tüneli kurar ve bağlar. Yönetici parolası bir kez sorulur.",
                           "Creates a free Cloudflare WARP account and WireGuard profile with wgcf, then sets up and connects the tunnel. You will be asked for your administrator password once."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(L("Açılışta otomatik bağlan", "Connect automatically at startup"), isOn: $startAtBoot)
                        .toggleStyle(.checkbox)
                        .disabled(wireGuardService.isProcessing)
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(L("Güvenlik uyarısı: Bu seçenek, Homebrew'un wg-quick, bash, wg ve wireguard-go programlarını her açılışta parola sormadan root (yönetici) olarak çalıştırır. Bu dosyaları kullanıcı hesabınız değiştirebildiğinden, hesabınızda çalışan kötü amaçlı bir program bunu yönetici yetkisi elde etmek için kullanabilir. Kapalıyken her bağlantıda parola sorulur. Değişiklik 'Yeniden Kur' ile uygulanır.",
                               "Security warning: this option runs Homebrew's wg-quick, bash, wg and wireguard-go as root at every startup without asking for a password. Because your user account can modify these files, malware running in your account could use this to gain administrator rights. When it is off, your password is asked on every connect. The change is applied with 'Reinstall'."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    let atBoot = startAtBoot
                    Task { await wireGuardService.install(startAtBoot: atBoot) }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(wireGuardService.isConfigured ? L("Yeniden Kur", "Reinstall") : L("Kur ve Bağlan", "Install and connect"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(wireGuardService.isProcessing)

                HStack(spacing: 8) {
                    Button {
                        Task { await wireGuardService.connect() }
                    } label: {
                        Label(L("Bağlan", "Connect"), systemImage: "play.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(wireGuardService.isProcessing
                              || !wireGuardService.isConfigured
                              || wireGuardService.isConnected)

                    Button {
                        Task { await wireGuardService.disconnect() }
                    } label: {
                        Label(L("Bağlantıyı Kes", "Disconnect"), systemImage: "stop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(wireGuardService.isProcessing || !wireGuardService.isConnected)
                }

                Divider()

                Button {
                    Task { await wireGuardService.uninstall() }
                } label: {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                        Text(L("WireGuard'ı Kaldır", "Uninstall WireGuard"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!wireGuardService.isConfigured || wireGuardService.isProcessing)
            }
            .padding()
        }
    }

    // MARK: - Bilgi

    private var infoSection: some View {
        GroupBox(label: Label(L("Nasıl çalışır?", "How does it work?"), systemImage: "info.circle")) {
            VStack(alignment: .leading, spacing: 8) {
                infoLine(L("Bağlıyken bu Mac'in TÜM internet trafiği ve DNS sorguları Cloudflare WARP üzerinden geçer. macOS'ta WireGuard uygulama bazlı tünellemeyi (yalnızca Discord gibi) desteklemez.",
                            "While connected, ALL of this Mac's internet traffic and DNS queries go through Cloudflare WARP. On macOS, WireGuard does not support per-app tunnelling (e.g. Discord only)."))
                infoLine(L("DNS de WARP üzerinden çözüldüğü için operatörün DNS engeli de aşılır.",
                            "Because DNS is also resolved through WARP, your ISP's DNS block is bypassed too."))
                infoLine(L("'Açılışta otomatik bağlan' seçiliyse tünel bilgisayar her açıldığında otomatik başlar ve 'Bağlantıyı Kes' yalnızca o oturum için kapatır; kalıcı olarak kapatmak için 'WireGuard'ı Kaldır'ı kullanın. Seçili değilse açılıştan sonra 'Bağlan'a basın.",
                            "If 'Connect automatically at startup' is selected, the tunnel starts every time the computer starts and 'Disconnect' only turns it off for the current session; to turn it off permanently, use 'Uninstall WireGuard'. Otherwise, press 'Connect' after startup."))
                infoLine(L("WARP bağlıyken ByeDPI'a gerek yoktur; ikisini aynı anda kullanmanız gerekmez.",
                            "ByeDPI is not needed while WARP is connected; you don't need to use both at the same time."))
                infoLine(L("Tüm trafik WARP'tan geçtiği için çevrim içi oyunlarda gecikme (ping) artar ve bazı oyunlarda sunucu değiştirme sorunları yaşanabilir. Roblox için önce ByeDPI + Sistem Proxy yolunu deneyin (ByeDPI sekmesi).",
                            "Because all traffic goes through WARP, online games get higher latency (ping) and some games may have trouble switching servers. For Roblox, try the ByeDPI + System proxy route first (ByeDPI tab)."))
                infoLine(L("Gereksinim: Homebrew ile kurulan wireguard-tools (\(WireGuardSupport.installCommandHint)). wgcf otomatik indirilir.",
                            "Requirement: wireguard-tools installed with Homebrew (\(WireGuardSupport.installCommandHint)). wgcf is downloaded automatically."))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Küçük bileşenler

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }

    private func prerequisiteRow(ok: Bool, title: String, detail: String, missingIsWarning: Bool = true) -> some View {
        HStack(alignment: .top) {
            Image(systemName: ok ? "checkmark.circle.fill" : (missingIsWarning ? "xmark.circle.fill" : "arrow.down.circle"))
                .foregroundColor(ok ? .green : (missingIsWarning ? .red : .secondary))
            Text(title)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func infoLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private var stateColor: Color {
        switch wireGuardService.connectionState {
        case .connected: return .green
        case .configured: return .orange
        case .notConfigured: return .secondary
        }
    }

    private var stateIcon: String {
        switch wireGuardService.connectionState {
        case .connected: return "checkmark.shield.fill"
        case .configured: return "shield"
        case .notConfigured: return "shield.slash"
        }
    }

    private var messageColor: Color {
        switch wireGuardService.statusKind {
        case .info: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    private var messageIcon: String {
        switch wireGuardService.statusKind {
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }
}
