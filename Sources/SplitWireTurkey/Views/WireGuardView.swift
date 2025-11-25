import SwiftUI

struct WireGuardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var wireGuardService = WireGuardService()
    @State private var showFolderPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status Section
                GroupBox(label: Label("WireGuard Durumu", systemImage: "network.badge.shield.half.filled")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Durum:")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(appState.wireGuardStatus)
                                .foregroundColor(appState.isWireGuardConfigured ? .green : .orange)
                        }

                        if appState.isWireGuardConfigured {
                            HStack {
                                Text("Yapılandırma:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("wgcf.conf")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                }

                // Installation Section
                GroupBox(label: Label("Kurulum", systemImage: "gearshape.2")) {
                    VStack(spacing: 16) {
                        // Browser Tunneling Toggle
                        Toggle("Tarayıcılar için de tünelleme yap", isOn: $appState.includeBrowsers)
                            .onChange(of: appState.includeBrowsers) { _ in
                                appState.saveSettings()
                            }

                        Divider()

                        // Standard Installation
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Standart Kurulum")
                                .font(.headline)
                            Text("WireGuard ve wgcf kullanarak Discord için tünelleme oluşturur.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: {
                                Task {
                                    await wireGuardService.installStandard(includeBrowsers: appState.includeBrowsers)
                                    await appState.checkWireGuardStatus()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Standart Kurulum Yap")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(wireGuardService.isProcessing)
                        }

                        Divider()

                        // Custom Installation Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Klasör Listesini Özelleştir")
                                .font(.headline)

                            // Custom Folders List
                            if !appState.customFolders.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(appState.customFolders, id: \.self) { folder in
                                            HStack {
                                                Text(folder)
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                Spacer()
                                                Button(action: {
                                                    appState.removeCustomFolder(folder)
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .foregroundColor(.red)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(4)
                                        }
                                    }
                                }
                                .frame(maxHeight: 100)
                            }

                            HStack(spacing: 8) {
                                Button(action: {
                                    showFolderPicker = true
                                }) {
                                    Label("Klasör Ekle", systemImage: "folder.badge.plus")
                                }

                                Button(action: {
                                    appState.clearCustomFolders()
                                }) {
                                    Label("Listeyi Temizle", systemImage: "trash")
                                }
                                .disabled(appState.customFolders.isEmpty)

                                Button(action: {
                                    Task {
                                        await wireGuardService.installCustom(
                                            customFolders: appState.customFolders,
                                            includeBrowsers: appState.includeBrowsers
                                        )
                                        await appState.checkWireGuardStatus()
                                    }
                                }) {
                                    Label("Özel Kurulum", systemImage: "gear.badge.checkmark")
                                }
                                .disabled(appState.customFolders.isEmpty || wireGuardService.isProcessing)
                            }
                        }

                        Divider()

                        // Uninstall
                        Button(action: {
                            Task {
                                await wireGuardService.uninstall()
                                await appState.checkWireGuardStatus()
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash.circle.fill")
                                Text("WireGuard'ı Kaldır")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(!appState.isWireGuardConfigured || wireGuardService.isProcessing)
                    }
                    .padding()
                }

                // Information
                GroupBox(label: Label("Bilgi", systemImage: "info.circle")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bu bölümdeki kurulumlar yalnızca Discord uygulaması için çalışır. Tarayıcı tünellemesi aktifse tarayıcılar da dahil edilir.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Sisteminizi yeniden başlattığınızda ilgili yöntem otomatik olarak çalışmaya başlar.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                if wireGuardService.isProcessing {
                    ProgressView(wireGuardService.statusMessage)
                        .progressViewStyle(.linear)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView { selectedFolder in
                if let folder = selectedFolder {
                    appState.addCustomFolder(folder.path)
                }
                showFolderPicker = false
            }
        }
    }
}

struct FolderPickerView: View {
    let onSelect: (URL?) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Klasör Seç")
                .font(.headline)

            Button("Klasör Seç") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false

                if panel.runModal() == .OK {
                    onSelect(panel.url)
                } else {
                    onSelect(nil)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("İptal") {
                onSelect(nil)
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}
