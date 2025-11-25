import SwiftUI

struct ByeDPIView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var byedpiService = ByeDPIService()
    @State private var showCustomArgs = false
    @State private var showSystemProxyInfo = false
    @State private var showAppPicker = false
    @State private var editingApp: AppState.FavoriteApp?
    @State private var statusCheckTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status Section
                GroupBox(label: Label("ByeDPI Durumu", systemImage: "network.badge.shield.half.filled")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Durum:")
                                .fontWeight(.semibold)
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(byedpiService.isRunning ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(byedpiService.isRunning ? "Çalışıyor" : "Durduruldu")
                                    .foregroundColor(byedpiService.isRunning ? .green : .red)
                            }
                        }

                        if byedpiService.isRunning {
                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("SOCKS5 Proxy Adresi:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("127.0.0.1:1080")
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding()
                }

                // Quick Actions - Customizable
                GroupBox(label: HStack {
                    Label("Hızlı İşlemler", systemImage: "bolt.fill")
                    Spacer()
                    Button(action: {
                        showAppPicker = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .help("Uygulama Ekle")
                }) {
                    VStack(spacing: 8) {
                        // Favorite Apps Grid
                        if !appState.favoriteApps.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(appState.favoriteApps) { app in
                                    FavoriteAppButton(
                                        app: app,
                                        byedpiService: byedpiService,
                                        onRemove: {
                                            appState.removeFavoriteApp(app)
                                        },
                                        onEdit: {
                                            editingApp = app
                                        }
                                    )
                                }
                            }
                        } else {
                            Text("Hızlı erişim için uygulama ekleyin")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }

                        Divider()

                        HStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    if byedpiService.isRunning {
                                        await byedpiService.stop()
                                    } else {
                                        await byedpiService.start()
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: byedpiService.isRunning ? "stop.circle.fill" : "play.circle.fill")
                                    Text(byedpiService.isRunning ? "Durdur" : "Başlat")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(byedpiService.isRunning ? .red : .green)
                            .disabled(byedpiService.isProcessing)

                            Button(action: {
                                Task {
                                    await byedpiService.killAllProcesses()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "xmark.octagon.fill")
                                    Text("Tümünü Kapat")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .disabled(byedpiService.isProcessing)
                            .help("Tüm ByeDPI process'lerini zorla kapat")
                        }

                        HStack(spacing: 12) {
                            Button(action: {
                                showSystemProxyInfo = true
                            }) {
                                HStack {
                                    Image(systemName: "network")
                                    Text("Sistem Proxy")
                                    if byedpiService.isSystemProxyEnabled {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!byedpiService.isRunning)
                        }
                    }
                    .padding()
                }

                // Preset Selection
                GroupBox(label: Label("Önceden Hazır Ayarlar", systemImage: "list.bullet.rectangle")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DPI aşım yöntemi seçin:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Preset", selection: $byedpiService.currentPreset) {
                            ForEach(Array(byedpiService.presets.keys.sorted()), id: \.self) { preset in
                                Text(preset).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)

                        if byedpiService.currentPreset != "Custom" {
                            if let args = byedpiService.presets[byedpiService.currentPreset] {
                                HStack {
                                    Text("Parametreler:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(args)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }

                        // Custom Args
                        if byedpiService.currentPreset == "Custom" || showCustomArgs {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Özel Parametreler")
                                        .font(.headline)
                                    Spacer()
                                    if !showCustomArgs && byedpiService.currentPreset != "Custom" {
                                        Button("Gizle") {
                                            showCustomArgs = false
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(.blue)
                                    }
                                }

                                TextEditor(text: $byedpiService.customArgs)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(height: 80)
                                    .border(Color.secondary.opacity(0.3), width: 1)
                                    .cornerRadius(4)

                                Text("Örnek: -r 1+s --disorder 1 --auto=torst")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if byedpiService.currentPreset != "Custom" {
                            Button(action: {
                                showCustomArgs.toggle()
                            }) {
                                HStack {
                                    Image(systemName: "pencil.circle")
                                    Text("Özel Parametreler Düzenle")
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding()
                }

                // Information
                GroupBox(label: Label("Nasıl Kullanılır?", systemImage: "questionmark.circle.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(
                            icon: "1.circle.fill",
                            title: "ByeDPI'ı Başlatın",
                            description: "Yukarıdaki 'Başlat' butonuna tıklayın."
                        )

                        InfoRow(
                            icon: "2.circle.fill",
                            title: "Uygulama Ekleyin",
                            description: "Hızlı İşlemler bölümündeki + butonuna tıklayarak favori uygulamalarınızı ekleyin."
                        )

                        InfoRow(
                            icon: "3.circle.fill",
                            title: "Uygulamayı Başlatın",
                            description: "Eklediğiniz uygulamanın ikonuna tıklayarak otomatik olarak ByeDPI ile başlatın."
                        )

                        Divider()

                        Text("**Not:** ByeDPI bir SOCKS5 proxy sunucusu oluşturur. Uygulamalar otomatik olarak bu proxy üzerinden çalışır.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Advanced Settings
                GroupBox(label: Label("Gelişmiş", systemImage: "gearshape.2.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Discord Ayarları")
                            .font(.headline)

                        Text("Discord'un otomatik güncellemelerini devre dışı bırakmak için settings.json dosyasına şu satırları ekleyin:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\"SKIP_HOST_UPDATE\": true,")
                                .font(.system(.caption, design: .monospaced))
                            Text("\"SKIP_MODULE_UPDATE\": true")
                                .font(.system(.caption, design: .monospaced))
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)

                        Button(action: {
                            let settingsPath = "~/Library/Application Support/discord/settings.json"
                            let command = "open -R '\(settingsPath)'"
                            Task {
                                try? await ByeDPIService().executeShellCommand(command)
                            }
                        }) {
                            HStack {
                                Image(systemName: "folder")
                                Text("settings.json Klasörünü Aç")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }

                if byedpiService.isProcessing {
                    ProgressView(byedpiService.statusMessage)
                        .progressViewStyle(.linear)
                }

                if !byedpiService.statusMessage.isEmpty && !byedpiService.isProcessing {
                    HStack {
                        Image(systemName: byedpiService.statusMessage.contains("Hata") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(byedpiService.statusMessage.contains("Hata") ? .red : .green)
                        Text(byedpiService.statusMessage)
                            .font(.caption)
                    }
                    .padding()
                    .background(byedpiService.statusMessage.contains("Hata") ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showSystemProxyInfo) {
            SystemProxyConfigView(byedpiService: byedpiService)
        }
        .sheet(isPresented: $showAppPicker) {
            AppPickerView(appState: appState, isPresented: $showAppPicker)
        }
        .sheet(item: $editingApp) { app in
            AppEditorView(appState: appState, app: app, onDismiss: {
                editingApp = nil
            })
        }
        .onAppear {
            startStatusCheck()
        }
        .onDisappear {
            stopStatusCheck()
        }
    }

    private func startStatusCheck() {
        // Initial check
        Task {
            await byedpiService.checkByeDPIStatus()
        }

        // Start periodic checking every 2 seconds
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                await byedpiService.checkByeDPIStatus()
            }
        }
    }

    private func stopStatusCheck() {
        statusCheckTimer?.invalidate()
        statusCheckTimer = nil
    }
}

struct FavoriteAppButton: View {
    let app: AppState.FavoriteApp
    let byedpiService: ByeDPIService
    let onRemove: () -> Void
    let onEdit: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: {
            Task {
                await byedpiService.startWithApp(appPath: app.path, appName: app.name, customArgs: app.customArgs)
            }
        }) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    // App Icon
                    if let icon = getAppIcon(path: app.path) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                    }

                    // App Name
                    Text(app.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(isHovering ? 0.5 : 0), lineWidth: 2)
                )

                // Action buttons
                if isHovering {
                    VStack(spacing: 4) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                                .background(Circle().fill(Color.white))
                        }
                        .buttonStyle(.plain)
                        .help("Parametreleri Düzenle")

                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .background(Circle().fill(Color.white))
                        }
                        .buttonStyle(.plain)
                        .help("Kaldır")
                    }
                    .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("ByeDPI ile \(app.name)'i Başlat")
    }

    private func getAppIcon(path: String) -> NSImage? {
        return NSWorkspace.shared.icon(forFile: path)
    }
}

struct AppPickerView: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Uygulama Seç")
                .font(.headline)

            Text("Hızlı erişim için eklemek istediğiniz uygulamayı seçin")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Applications Klasöründen Seç") {
                selectApp()
            }
            .buttonStyle(.borderedProminent)

            Button("İptal") {
                isPresented = false
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 400, height: 200)
    }

    private func selectApp() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            let appName = url.deletingPathExtension().lastPathComponent
            let bundleID = Bundle(url: url)?.bundleIdentifier

            let favoriteApp = AppState.FavoriteApp(
                name: appName,
                path: url.path,
                bundleIdentifier: bundleID
            )

            appState.addFavoriteApp(favoriteApp)
            isPresented = false
        }
    }
}

struct AppEditorView: View {
    @ObservedObject var appState: AppState
    let app: AppState.FavoriteApp
    let onDismiss: () -> Void

    @State private var editedArgs: String = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                if let icon = NSWorkspace.shared.icon(forFile: app.path) as NSImage? {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                }
                VStack(alignment: .leading) {
                    Text(app.name)
                        .font(.headline)
                    Text(app.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Başlatma Parametreleri")
                    .font(.headline)

                Text("Uygulama başlatılırken kullanılacak komut satırı parametreleri:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $editedArgs)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                    .border(Color.secondary.opacity(0.3), width: 1)
                    .cornerRadius(4)

                Text("Varsayılan: --proxy-server=socks5://127.0.0.1:1080")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Varsayılana Sıfırla") {
                    editedArgs = "--proxy-server=socks5://127.0.0.1:1080"
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.caption)
            }

            Divider()

            HStack(spacing: 12) {
                Button("İptal") {
                    onDismiss()
                }
                .buttonStyle(.bordered)

                Button("Kaydet") {
                    var updatedApp = app
                    updatedApp.customArgs = editedArgs
                    appState.updateFavoriteApp(updatedApp)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500, height: 350)
        .onAppear {
            editedArgs = app.customArgs
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SystemProxyConfigView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var byedpiService: ByeDPIService
    @State private var isLoading = true
    @State private var isToggling = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Sistem Proxy Yapılandırması")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("Bu seçenek sistem genelinde SOCKS5 proxy ayarları yapar.")
                    .font(.body)

                Text("Etkinleştirildiğinde, tüm uygulamalar ByeDPI üzerinden bağlanır.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                HStack {
                    Text("Sistem Proxy Durumu:")
                        .fontWeight(.medium)
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(byedpiService.isSystemProxyEnabled ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(byedpiService.isSystemProxyEnabled ? "Açık" : "Kapalı")
                                .foregroundColor(byedpiService.isSystemProxyEnabled ? .green : .red)
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            isToggling = true
                            await byedpiService.configureSystemProxy(enable: true)
                            await byedpiService.checkSystemProxyStatus()
                            isToggling = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Aç")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isToggling || byedpiService.isSystemProxyEnabled)

                    Button(action: {
                        Task {
                            isToggling = true
                            await byedpiService.configureSystemProxy(enable: false)
                            await byedpiService.checkSystemProxyStatus()
                            isToggling = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Kapat")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isToggling || !byedpiService.isSystemProxyEnabled)
                }

                if isToggling {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("İşlem yapılıyor...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            Button("Kapat") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 450, height: 350)
        .onAppear {
            Task {
                await byedpiService.checkSystemProxyStatus()
                isLoading = false
            }
        }
    }
}
