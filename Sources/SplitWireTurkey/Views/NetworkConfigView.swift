import SwiftUI

struct NetworkConfigView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var networkService = NetworkConfigService.shared
    @ObservedObject private var checker = DNSHealthChecker.shared
    @State private var showDoHSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DNSHealthBanner(showOKLine: true)
                currentDNSSection
                presetsSection
                dohSection
                statusView
            }
            .padding()
        }
        .sheet(isPresented: $showDoHSheet) {
            DoHProfileSheet(isPresented: $showDoHSheet)
        }
        .task {
            await networkService.loadNetworkInfo()
            await checker.checkIfNeeded()
        }
    }

    // MARK: - Bölümler

    private var currentDNSSection: some View {
        GroupBox(label: Label(L("Mevcut DNS", "Current DNS"), systemImage: "network")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L("Ağ servisi:", "Network service:"))
                        .fontWeight(.semibold)
                    Text(networkService.hasLoaded ? networkService.serviceDisplayName : L("Alınıyor...", "Loading..."))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        Task {
                            await networkService.loadNetworkInfo()
                            await checker.check()
                        }
                    } label: {
                        Label(L("Yenile", "Refresh"), systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .disabled(networkService.isBusy || checker.isChecking)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(L("DNS sunucuları:", "DNS servers:"))
                        .fontWeight(.semibold)
                    if !networkService.hasLoaded {
                        Text(L("Alınıyor...", "Loading...")).foregroundColor(.secondary)
                    } else if networkService.isDHCP {
                        Text(L("DHCP (otomatik)", "DHCP (automatic)"))
                            .foregroundColor(.secondary)
                        if !networkService.effectiveDNS.isEmpty {
                            dnsChips(networkService.effectiveDNS)
                        }
                    } else {
                        dnsChips(networkService.manualDNS)
                        if let preset = networkService.activePreset {
                            Text(preset.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private var presetsSection: some View {
        GroupBox(label: Label(L("DNS Sunucusu Seç", "Choose DNS server"), systemImage: "server.rack")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(presetsHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await networkService.apply(.cloudflare) }
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text(L("\(DNSPreset.cloudflare.title) — Önerilen",
                               "\(DNSPreset.cloudflare.title) — Recommended"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: 8) {
                    ForEach([DNSPreset.google, .quad9]) { preset in
                        Button {
                            Task { await networkService.apply(preset) }
                        } label: {
                            Text(preset.title).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        Task { await networkService.resetToDHCP() }
                    } label: {
                        Label(L("DHCP'ye Sıfırla", "Reset to DHCP"), systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await networkService.flushDNSCache() }
                    } label: {
                        Label(L("DNS Önbelleğini Temizle", "Flush DNS cache"), systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(8)
            .disabled(networkService.isBusy)
        }
    }

    private var dohSection: some View {
        GroupBox(label: Label(L("Şifreli DNS (DNS over HTTPS)", "Encrypted DNS (DNS over HTTPS)"), systemImage: "lock.shield")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("DNS'i 1.1.1.1 yapmak uyarıyı gidermediyse internet sağlayıcınız DNS trafiğini (53. port) yakalıyor olabilir. Cloudflare DoH profili sorguları HTTPS üzerinden şifreli gönderir ve bu müdahaleyi aşar. Profili siz Sistem Ayarları'ndan yüklersiniz; istediğiniz zaman kaldırabilirsiniz.",
                       "If setting DNS to 1.1.1.1 didn't clear the warning, your ISP may be intercepting DNS traffic (port 53). The Cloudflare DoH profile sends queries encrypted over HTTPS and gets around this interference. You install the profile yourself in System Settings and can remove it at any time."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showDoHSheet = true
                } label: {
                    Label(L("Şifreli DNS (DoH) Profili…", "Encrypted DNS (DoH) profile…"), systemImage: "lock.shield")
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if networkService.isBusy || !networkService.statusMessage.isEmpty {
            HStack(spacing: 8) {
                if networkService.isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                }
                Text(networkService.statusMessage)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(10)
            .background(statusColor.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Yardımcılar

    /// Seçimin hangi servise uygulanacağını anlatan açıklama.
    private var presetsHint: String {
        if let service = networkService.serviceName {
            return L("Seçim \"\(service)\" servisine uygulanır ve DNS önbelleği temizlenir (yönetici parolası istenir).",
                     "The selection is applied to the \"\(service)\" service and the DNS cache is flushed (administrator password required).")
        }
        return L("Seçim birincil ağ servisine uygulanır ve DNS önbelleği temizlenir (yönetici parolası istenir).",
                 "The selection is applied to the primary network service and the DNS cache is flushed (administrator password required).")
    }

    private func dnsChips(_ servers: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(servers, id: \.self) { dns in
                Text(dns)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }

    private var statusIcon: String {
        switch networkService.statusKind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private var statusColor: Color {
        switch networkService.statusKind {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}
