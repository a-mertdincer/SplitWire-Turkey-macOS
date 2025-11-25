import SwiftUI

struct NetworkConfigView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var networkService = NetworkConfigService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // DNS Configuration
                GroupBox(label: Label("DNS Yapılandırması", systemImage: "network")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mevcut DNS Sunucuları")
                            .font(.headline)

                        if networkService.currentDNS.isEmpty {
                            Text("DNS bilgisi alınıyor...")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(networkService.currentDNS, id: \.self) { dns in
                                Text(dns)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }

                        Divider()

                        VStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    await networkService.setOptimalDNS()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                    Text("Optimal DNS Ayarla (Google + Quad9)")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button(action: {
                                Task {
                                    await networkService.resetDNS()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("DNS Ayarlarını Sıfırla (DHCP)")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }

                // Network Interface Info
                GroupBox(label: Label("Ağ Arayüzü Bilgileri", systemImage: "cable.connector")) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let interface = networkService.primaryInterface {
                            HStack {
                                Text("Birincil Arayüz:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(interface)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Ağ arayüzü bilgisi alınıyor...")
                                .foregroundColor(.secondary)
                        }

                        Button("Bilgileri Yenile") {
                            Task {
                                await networkService.loadNetworkInfo()
                            }
                        }
                    }
                    .padding()
                }

                // Advanced Settings
                GroupBox(label: Label("Gelişmiş Ayarlar", systemImage: "gearshape.2.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bu bölüm gelişmiş kullanıcılar içindir.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: {
                            Task {
                                await networkService.flushDNSCache()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("DNS Önbelleğini Temizle")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }

                // Status Messages
                if !networkService.statusMessage.isEmpty {
                    HStack {
                        Image(systemName: networkService.hasError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(networkService.hasError ? .red : .green)
                        Text(networkService.statusMessage)
                            .font(.caption)
                    }
                    .padding()
                    .background(networkService.hasError ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .onAppear {
            Task {
                await networkService.loadNetworkInfo()
            }
        }
    }
}
