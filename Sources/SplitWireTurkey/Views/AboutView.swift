import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Uygulama simgesi ve sürüm
                VStack(spacing: 12) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.accentColor)

                    Text("SplitWire-Turkey")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(versionText)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding()

                Divider()

                // Açıklama
                GroupBox(label: Label(L("Hakkında", "About"), systemImage: "info.circle.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L(
                            "SplitWire-Turkey, Türkiye'deki internet kullanıcılarının DPI (derin paket inceleme) ve DNS tabanlı engelleri aşması için hazırlanmış bir araçtır.",
                            "SplitWire-Turkey helps internet users in Türkiye get around DPI (deep packet inspection) and DNS-based blocking."
                        ))
                        .fixedSize(horizontal: false, vertical: true)

                        Text(L(
                            "Bu macOS uyarlaması, Çağrı Taşkın'ın Windows için geliştirdiği orijinal SplitWire-Turkey uygulamasının temel özelliklerini macOS'a taşır.",
                            "This macOS port brings the core features of Çağrı Taşkın's original SplitWire-Turkey for Windows to the Mac."
                        ))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }

                // Özellikler
                GroupBox(label: Label(L("Özellikler", "Features"), systemImage: "star.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(
                            icon: "shield.checkered",
                            text: L("ByeDPI ile DPI aşımı (yerel SOCKS5 proxy)", "DPI bypass with ByeDPI (local SOCKS5 proxy)")
                        )
                        FeatureRow(
                            icon: "app.badge",
                            text: L(
                                "Discord ve diğer Chromium/Electron uygulamalarını proxy ile başlatma",
                                "Launch Discord and other Chromium/Electron apps through the proxy"
                            )
                        )
                        FeatureRow(
                            icon: "network",
                            text: L("Cloudflare WARP (WireGuard) tüneli", "Cloudflare WARP (WireGuard) tunnel")
                        )
                        FeatureRow(
                            icon: "gearshape.2",
                            text: L(
                                "DNS engeli kontrolü, kolay DNS ve DNS-over-HTTPS ayarı",
                                "DNS blocking check, easy DNS and DNS-over-HTTPS setup"
                            )
                        )
                        FeatureRow(
                            icon: "menubar.rectangle",
                            text: L("Menü çubuğundan hızlı kontrol", "Quick controls in the menu bar")
                        )
                    }
                    .padding()
                }

                // Teşekkürler
                GroupBox(label: Label(L("Emeği Geçenler", "Credits"), systemImage: "heart.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // macOS uyarlaması
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("macOS uyarlaması", "macOS port"))
                                .fontWeight(.semibold)

                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mert Dinçer")
                                        .fontWeight(.medium)
                                    LinkButton(title: "@a-mertdincer", url: AppInfo.authorURL)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Divider()

                        CreditRow(
                            title: L("Orijinal SplitWire-Turkey (Windows)", "Original SplitWire-Turkey (Windows)"),
                            detail: "Çağrı Taşkın — @cagritaskn",
                            url: AppInfo.originalProjectURL
                        )

                        CreditRow(
                            title: "ByeDPI (ciadpi)",
                            detail: L("hufrea — DPI aşım aracı", "hufrea — DPI bypass tool"),
                            url: AppInfo.byedpiURL
                        )

                        CreditRow(
                            title: "wgcf",
                            detail: L("ViRb3 — Cloudflare WARP profil aracı", "ViRb3 — Cloudflare WARP profile generator"),
                            url: AppInfo.wgcfURL
                        )

                        CreditRow(
                            title: "WireGuard",
                            detail: "wireguard-tools, wireguard-go",
                            url: AppInfo.wireGuardURL
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }

                // Lisans
                GroupBox(label: Label(L("Lisans", "License"), systemImage: "doc.text.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("MIT Lisansı", "MIT License"))
                            .fontWeight(.semibold)
                        Text("Copyright © 2025 Mert Dinçer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(L(
                            "ByeDPI, wgcf ve WireGuard kendi lisanslarıyla dağıtılır.",
                            "ByeDPI, wgcf and WireGuard are distributed under their own licenses."
                        ))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }

                // Bağlantılar
                HStack(spacing: 8) {
                    LinkCardButton(
                        title: L("GitHub Sayfası", "GitHub page"),
                        systemImage: "link.circle.fill",
                        url: AppInfo.repositoryURL
                    )
                    LinkCardButton(
                        title: L("Sorun Bildir", "Report an issue"),
                        systemImage: "exclamationmark.bubble.fill",
                        url: AppInfo.issuesURL
                    )
                    LinkCardButton(
                        title: L("Sürümler", "Releases"),
                        systemImage: "arrow.down.circle.fill",
                        url: AppInfo.releasesURL
                    )
                }

                Spacer()
            }
            .padding()
        }
    }

    private var versionText: String {
        let version = AppInfo.version
        if let base = AppInfo.build {
            let build = AppInfo.commit.map { "\(base), \($0)" } ?? base
            return L("macOS için · Sürüm \(version) (\(build))", "for macOS · Version \(version) (\(build))")
        }
        return L("macOS için · Sürüm \(version)", "for macOS · Version \(version)")
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.accentColor)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

/// Başlık + açıklama + bağlantı satırı (Emeği Geçenler bölümü).
private struct CreditRow: View {
    let title: String
    let detail: String
    let url: URL

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            LinkButton(title: Self.displayString(for: url), url: url)
        }
    }

    /// "https://github.com/hufrea/byedpi" → "github.com/hufrea/byedpi"
    static func displayString(for url: URL) -> String {
        let host = url.host ?? url.absoluteString
        let path = url.path == "/" ? "" : url.path
        return host + path
    }
}

/// Küçük, mavi bağlantı düğmesi.
private struct LinkButton: View {
    let title: String
    let url: URL

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "link")
                Text(title)
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .help(url.absoluteString)
    }
}

/// Alt kısımdaki geniş bağlantı düğmesi.
private struct LinkCardButton: View {
    let title: String
    let systemImage: String
    let url: URL

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .help(url.absoluteString)
    }
}
