import SwiftUI

struct ByeDPIView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var byedpiService: ByeDPIService
    @EnvironmentObject var systemProxy: SystemProxyService
    @State private var showSystemProxyInfo = false
    @State private var showAppPicker = false
    @State private var editingApp: AppState.FavoriteApp?

    private var presetBinding: Binding<String> {
        Binding(
            get: { byedpiService.currentPreset },
            set: { byedpiService.selectPreset($0) }
        )
    }

    /// ByeDPI veya sistem proxy işlemi (parola penceresi dahil) sürüyor.
    private var isBusy: Bool {
        byedpiService.isProcessing || systemProxy.isBusy
    }

    private var isCustomSelected: Bool {
        byedpiService.currentPreset == ByeDPIPresets.customID
    }

    /// Çalışan yöntemin görünen adı (id kalıcıdır, ad yerelleştirilebilir).
    private var runningPresetDisplayName: String {
        guard let id = byedpiService.runningPreset else {
            return L("harici süreç", "external process")
        }
        return ByeDPIPresets.preset(id: id)?.name ?? id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DNSHealthBanner()
                statusSection
                quickActionsSection
                presetSection
                howToSection
                advancedSection
                statusMessageView
            }
            .padding()
        }
        .sheet(isPresented: $showSystemProxyInfo) {
            SystemProxyConfigView(byedpiService: byedpiService, systemProxy: systemProxy)
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
            Task {
                await byedpiService.refreshStatus()
                await systemProxy.refresh()
            }
        }
    }

    // MARK: - Bölümler

    private var statusSection: some View {
        GroupBox(label: Label(L("ByeDPI Durumu", "ByeDPI status"), systemImage: "network.badge.shield.half.filled")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L("Durum:", "Status:"))
                        .fontWeight(.semibold)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(byedpiService.isRunning ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(byedpiService.isRunning
                             ? (byedpiService.isExternallyStarted
                                ? L("Çalışıyor (harici süreç)", "Running (external process)")
                                : L("Çalışıyor", "Running"))
                             : L("Durduruldu", "Stopped"))
                            .foregroundColor(byedpiService.isRunning ? .green : .red)
                    }
                }

                if byedpiService.isRunning {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Proxy Adresi (SOCKS5 ve HTTPS):", "Proxy address (SOCKS5 and HTTPS):"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(byedpiService.proxyAddress)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Çalışan yöntem: \(runningPresetDisplayName)",
                               "Active method: \(runningPresetDisplayName)"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let args = byedpiService.runningArgs {
                            Text(args)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        if byedpiService.isExposedToNetwork {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(ByeDPIService.exposedWarning.resolved
                                     + " " + L("Durdurup yeniden başlatın: yeni süreç yalnızca 127.0.0.1'de dinler.",
                                               "Stop and start it again: the new process listens on 127.0.0.1 only."))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if byedpiService.isExternallyStarted {
                            Text(L("Bu ciadpi süreci bu oturumda başlatılmadı (ör. önceki oturumdan kalmış). Seçili yöntemi uygulamak için durdurup yeniden başlatın.",
                                   "This ciadpi process wasn't started in this session (e.g. it was left over from a previous session). Stop and start it again to apply the selected method."))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    Divider()

                    ConnectionTestView(byedpiService: byedpiService)
                }

                if systemProxy.isOurProxyActive {
                    Divider()
                    if byedpiService.isRunning {
                        HStack(spacing: 6) {
                            Image(systemName: "network")
                                .foregroundColor(.green)
                            let services = systemProxy.activeSummary
                            Text(L("Sistem proxy açık (\(services)). ByeDPI durdurulduğunda otomatik kapatılır.",
                                   "System proxy is on (\(services)). It turns off automatically when ByeDPI stops."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L("Sistem proxy açık ama ByeDPI çalışmıyor — internet bağlantınız çalışmaz.",
                                       "System proxy is on but ByeDPI isn't running — your internet connection won't work."))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                HStack {
                                    Button(L("Sistem Proxy'yi Kapat", "Turn off system proxy")) {
                                        Task { await byedpiService.disableSystemProxy() }
                                    }
                                    .disabled(systemProxy.isBusy)
                                    Button(L("ByeDPI'ı Başlat", "Start ByeDPI")) {
                                        Task { await byedpiService.start() }
                                    }
                                    .disabled(byedpiService.isProcessing)
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(6)
                    }
                }
            }
            .padding()
        }
    }

    private var quickActionsSection: some View {
        GroupBox(label: HStack {
            Label(L("Hızlı İşlemler", "Quick actions"), systemImage: "bolt.fill")
            Spacer()
            Button(action: {
                showAppPicker = true
            }) {
                Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.plain)
            .help(L("Uygulama Ekle", "Add app"))
        }) {
            VStack(spacing: 8) {
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
                    Text(L("Hızlı erişim için uygulama ekleyin", "Add apps for quick access"))
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
                            Text(byedpiService.isRunning ? L("Durdur", "Stop") : L("Başlat", "Start"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(byedpiService.isRunning ? .red : .green)
                    .disabled(isBusy)

                    Button(action: {
                        Task {
                            await byedpiService.killAllProcesses()
                        }
                    }) {
                        HStack {
                            Image(systemName: "xmark.octagon.fill")
                            Text(L("Tümünü Zorla Kapat", "Force stop all"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isBusy)
                    .help(L("Tüm ciadpi süreçlerini zorla kapatır (gerekirse yönetici izni ister)",
                            "Force-stops all ciadpi processes (asks for administrator permission if needed)"))
                }

                HStack(spacing: 12) {
                    Button(action: {
                        showSystemProxyInfo = true
                    }) {
                        HStack {
                            Image(systemName: "network")
                            Text(L("Sistem Proxy", "System proxy"))
                            if systemProxy.isOurProxyActive {
                                Circle()
                                    .fill(byedpiService.isRunning ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!byedpiService.isRunning && !systemProxy.isOurProxyActive)
                }
            }
            .padding()
        }
    }

    private var presetSection: some View {
        GroupBox(label: Label(L("Önceden Hazır Ayarlar", "Presets"), systemImage: "list.bullet.rectangle")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("DPI aşım yöntemi seçin (çalışıyorsa seçilen yöntemle yeniden başlatılır):",
                       "Choose a DPI bypass method (ByeDPI restarts with it if it is running):"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker(L("Yöntem", "Method"), selection: presetBinding) {
                    ForEach(byedpiService.presets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isBusy)

                if isCustomSelected {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Özel Parametreler", "Custom parameters"))
                            .font(.headline)

                        TextEditor(text: $byedpiService.customArgs)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 80)
                            .border(Color.secondary.opacity(0.3), width: 1)
                            .cornerRadius(4)

                        HStack {
                            Text(L("Örnek: -s 2 --tlsrec 1+s   (-i 127.0.0.1, -p 1080 ve -G otomatik eklenir)",
                                   "Example: -s 2 --tlsrec 1+s   (-i 127.0.0.1, -p 1080 and -G are added automatically)"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(L("Uygula", "Apply")) {
                                byedpiService.applyCustomArgs()
                            }
                            .disabled(isBusy
                                      || ByeDPIArguments.tokenize(byedpiService.customArgs).isEmpty)
                            .help(L("Çalışıyorsa ByeDPI'ı bu parametrelerle yeniden başlatır",
                                    "Restarts ByeDPI with these parameters if it is running"))
                        }
                    }
                } else {
                    HStack {
                        Text(L("Parametreler:", "Parameters:"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(byedpiService.args(for: byedpiService.currentPreset))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)

                    Button(action: {
                        byedpiService.editAsCustom()
                    }) {
                        HStack {
                            Image(systemName: "pencil.circle")
                            Text(L("Özel Parametreleri Düzenle", "Edit custom parameters"))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .disabled(isBusy)
                    .help(L("Özel (Custom) moduna geçer; özel parametreler boşsa veya değiştirilmemişse bu yöntemin parametreleriyle doldurulur",
                            "Switches to Custom mode; prefills with this method's parameters unless you have saved your own"))
                }
            }
            .padding()
        }
    }

    private var howToSection: some View {
        GroupBox(label: Label(L("Nasıl Kullanılır?", "How to use"), systemImage: "questionmark.circle.fill")) {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    icon: "1.circle.fill",
                    title: L("ByeDPI'ı Başlatın", "Start ByeDPI"),
                    description: L("Yukarıdaki 'Başlat' butonuna tıklayın.",
                                   "Click the 'Start' button above.")
                )

                InfoRow(
                    icon: "2.circle.fill",
                    title: L("Uygulama Ekleyin", "Add apps"),
                    description: L("Hızlı İşlemler bölümündeki + butonuna tıklayarak favori uygulamalarınızı ekleyin.",
                                   "Click the + button in the Quick actions section to add your favorite apps.")
                )

                InfoRow(
                    icon: "3.circle.fill",
                    title: L("Uygulamayı Başlatın", "Launch the app"),
                    description: L("Eklediğiniz uygulamanın ikonuna tıklayın; uygulama ByeDPI proxy ayarıyla başlatılır (çalışıyorsa yeniden başlatılması önerilir).",
                                   "Click the icon of an app you added; it launches with the ByeDPI proxy setting (if it is already running, restarting it is recommended).")
                )

                Divider()

                // Markdown (**kalın**) içerdiği için LocalizedStringKey ile gösterilir.
                Text(LocalizedStringKey(L(
                    "**Not:** ByeDPI yerel bir proxy (\(byedpiService.proxyAddress), SOCKS5 ve HTTPS) oluşturur. Hızlı İşlemler'den açılan uygulamalara hem proxy parametresi (Chromium/Electron: Discord, Chrome, Brave, Edge, Slack, Spotify…) hem de HTTPS_PROXY ortam değişkeni (Discord'un güncelleme denetimi, Roblox ve bu değişkeni okuyan diğer uygulamalar) verilir. Safari gibi macOS proxy ayarlarını kullanan uygulamalar için 'Sistem Proxy'yi, hiçbirini kullanmayan uygulamalar için WireGuard'ı kullanın.",
                    "**Note:** ByeDPI creates a local proxy (\(byedpiService.proxyAddress), SOCKS5 and HTTPS). Apps opened from Quick actions get both the proxy parameter (Chromium/Electron: Discord, Chrome, Brave, Edge, Slack, Spotify…) and the HTTPS_PROXY environment variable (Discord's update check, Roblox and other apps that read it). For apps that use the macOS proxy settings, such as Safari, use 'System proxy'; for apps that use neither, use WireGuard."
                )))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                RobloxGuideNote(onAddRoblox: robloxToAdd.map { url in { addRobloxFavorite(url) } })
            }
            .padding()
        }
    }

    /// Kurulu ama Hızlı İşlemler'de olmayan Roblox uygulaması (#13).
    private var robloxToAdd: URL? {
        guard let url = RobloxGuideNote.installedRobloxURL(),
              !appState.isFavorite(url.path) else { return nil }
        return url
    }

    private func addRobloxFavorite(_ url: URL) {
        // Roblox proxy parametresini tanımaz; HTTPS_PROXY ile açılması yeterli
        appState.addFavoriteApp(AppState.FavoriteApp(
            name: url.deletingPathExtension().lastPathComponent,
            path: url.path,
            bundleIdentifier: Bundle(url: url)?.bundleIdentifier,
            customArgs: ""
        ))
    }

    private var advancedSection: some View {
        GroupBox(label: Label(L("Gelişmiş", "Advanced"), systemImage: "gearshape.2.fill")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("Discord \"Checking for updates…\" ekranında kalıyorsa", "If Discord stays on \"Checking for updates…\""))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("• Discord açılışta güncelleme denetimi yapar ve bu denetim başarılı olmadan açılmaz. Denetim proxy parametresini yok sayar (0.0.419 öncesi sürümler sistem proxy'sini de); SplitWire bu yüzden Discord'u HTTPS_PROXY ortam değişkeniyle başlatır. Discord'u Hızlı İşlemler'den açın. (Discord 0.0.419 ve sonrasını Dock'tan açmak isterseniz ByeDPI çalışırken Sistem Proxy'yi açmak da işe yarar.)",
                           "• Discord checks for updates at startup and doesn't open until that check succeeds. The check ignores the proxy parameter (versions before 0.0.419 ignore the system proxy too), so SplitWire launches Discord with the HTTPS_PROXY environment variable. Open Discord from Quick actions. (To open Discord 0.0.419 or later from the Dock, turning on System proxy while ByeDPI runs also works.)"))
                    Text(L("• Denetim TLS 1.2 kullanır ve her yöntemle geçmez. Yukarıdaki bağlantı testinde \"Discord güncelleme denetimi\" başarısızsa önerilen yöntemi seçin.",
                           "• The check uses TLS 1.2 and doesn't get through with every method. If \"Discord update check\" fails in the connection test above, choose the recommended method."))
                    Text(L("• Discord güncellemeyi kurduktan sonra kendini proxy'siz yeniden açar; SplitWire bunu algılar ve Discord'u ByeDPI ile otomatik olarak yeniden açar.",
                           "• After installing an update, Discord reopens itself without the proxy; SplitWire detects this and reopens Discord with ByeDPI automatically."))
                    Text(L("• Eski rehberlerdeki SKIP_HOST_UPDATE / SKIP_MODULE_UPDATE ayarları güncel macOS Discord'da etkisizdir; gerek yoktur.",
                           "• The SKIP_HOST_UPDATE / SKIP_MODULE_UPDATE settings from older guides have no effect on current macOS Discord; you don't need them."))
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Button(action: openDiscordLogsFolder) {
                    HStack {
                        Image(systemName: "folder")
                        Text(L("Discord Günlüklerini Aç", "Open Discord logs"))
                    }
                }
                .buttonStyle(.bordered)
                .help(L("Sorun bildirirken eklemek için Discord'un günlük klasörünü Finder'da açar",
                        "Opens Discord's log folder in Finder, to attach when reporting a problem"))
            }
            .padding()
        }
    }

    @ViewBuilder
    private var statusMessageView: some View {
        if byedpiService.isProcessing {
            ProgressView(byedpiService.statusMessage)
                .progressViewStyle(.linear)
        } else if !byedpiService.statusMessage.isEmpty {
            let style = StatusStyle(kind: byedpiService.statusKind)
            HStack(alignment: .top) {
                Image(systemName: style.icon)
                    .foregroundColor(style.color)
                Text(byedpiService.statusMessage)
                    .font(.caption)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding()
            .background(style.color.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func openDiscordLogsFolder() {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/discord", isDirectory: true)
        let logs = folder.appendingPathComponent("logs", isDirectory: true)
        // macOS başka uygulamanın verisine erişimi engelleyebilir; Finder'a açtırmak yeterli
        if FileManager.default.fileExists(atPath: logs.path) {
            NSWorkspace.shared.open(logs)
        } else if FileManager.default.fileExists(atPath: folder.path) {
            NSWorkspace.shared.open(folder)
        } else {
            let alert = NSAlert()
            alert.messageText = L("Klasör bulunamadı", "Folder not found")
            alert.informativeText = L(
                "Discord ayar klasörü bulunamadı:\n\(folder.path)\n\nDiscord'u en az bir kez açtığınızdan emin olun.",
                "Couldn't find the Discord settings folder:\n\(folder.path)\n\nMake sure you have opened Discord at least once."
            )
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("Tamam", "OK"))
            alert.runModal()
        }
    }
}

/// Durum türüne göre simge/renk.
private struct StatusStyle {
    let icon: String
    let color: Color

    init(kind: ByeDPIStatusKind) {
        switch kind {
        case .info:
            icon = "info.circle.fill"; color = .blue
        case .success:
            icon = "checkmark.circle.fill"; color = .green
        case .warning:
            icon = "exclamationmark.triangle.fill"; color = .orange
        case .error:
            icon = "xmark.octagon.fill"; color = .red
        }
    }
}

struct FavoriteAppButton: View {
    let app: AppState.FavoriteApp
    @ObservedObject var byedpiService: ByeDPIService
    let onRemove: () -> Void
    let onEdit: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: {
            Task {
                await byedpiService.launchFavoriteApp(app)
            }
        }) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                        .resizable()
                        .frame(width: 48, height: 48)

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

                if isHovering {
                    VStack(spacing: 4) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                                .background(Circle().fill(Color.white))
                        }
                        .buttonStyle(.plain)
                        .help(L("Parametreleri Düzenle", "Edit parameters"))

                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .background(Circle().fill(Color.white))
                        }
                        .buttonStyle(.plain)
                        .help(L("Kaldır", "Remove"))
                    }
                    .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(byedpiService.isProcessing)
        .onHover { hovering in
            isHovering = hovering
        }
        // "'i" eki her uygulama adına uymadığından (ör. Discord'u) ekten kaçınılır.
        .help(L("\(app.name) uygulamasını ByeDPI ile başlat", "Launch \(app.name) with ByeDPI"))
    }
}

struct AppPickerView: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text(L("Uygulama Seç", "Choose an app"))
                .font(.headline)

            Text(L("Hızlı erişim için eklemek istediğiniz uygulamayı seçin",
                   "Choose the app you want to add for quick access"))
                .font(.caption)
                .foregroundColor(.secondary)

            Button(L("Applications Klasöründen Seç", "Choose from Applications folder")) {
                selectApp()
            }
            .buttonStyle(.borderedProminent)

            Button(L("İptal", "Cancel")) {
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

    private static let defaultArgs = "--proxy-server=socks5://127.0.0.1:1080"

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    .resizable()
                    .frame(width: 48, height: 48)
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
                Text(L("Başlatma Parametreleri", "Launch parameters"))
                    .font(.headline)

                Text(L("Uygulama başlatılırken kullanılacak komut satırı parametreleri:",
                       "Command-line parameters used when launching the app:"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $editedArgs)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                    .border(Color.secondary.opacity(0.3), width: 1)
                    .cornerRadius(4)

                Text(L("Varsayılan: \(Self.defaultArgs)", "Default: \(Self.defaultArgs)"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(L("Not: Proxy parametresi yalnızca Chromium/Electron tabanlı uygulamalarda çalışır (Discord, Chrome, Brave, Edge, Slack, Spotify…). SplitWire ayrıca HTTPS_PROXY ortam değişkenini verir; Discord'un güncelleme denetimi ve Roblox bunu kullanır. Safari gibi macOS proxy ayarlarını kullanan uygulamalar için 'Sistem Proxy'yi, hiçbirini kullanmayanlar için WireGuard'ı kullanın.",
                       "Note: The proxy parameter only works in Chromium/Electron-based apps (Discord, Chrome, Brave, Edge, Slack, Spotify…). SplitWire also sets the HTTPS_PROXY environment variable, which Discord's update check and Roblox use. For apps that use the macOS proxy settings, such as Safari, use 'System proxy'; for apps that use neither, use WireGuard."))
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)

                Button(L("Varsayılana Sıfırla", "Reset to default")) {
                    editedArgs = Self.defaultArgs
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.caption)
            }

            Divider()

            HStack(spacing: 12) {
                Button(L("İptal", "Cancel")) {
                    onDismiss()
                }
                .buttonStyle(.bordered)

                Button(L("Kaydet", "Save")) {
                    var updatedApp = app
                    updatedApp.customArgs = editedArgs
                    appState.updateFavoriteApp(updatedApp)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500, height: 440)
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
    @ObservedObject var systemProxy: SystemProxyService
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 20) {
            Text(L("Sistem Proxy Yapılandırması", "System proxy settings"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text(L("Bu seçenek etkin ağ servisinde hem SOCKS proxy hem de güvenli web proxy'si (HTTPS) olarak \(byedpiService.proxyAddress) adresini ayarlar; proxy parametresini desteklemeyen ama macOS proxy ayarlarını kullanan uygulamalar (ör. Safari) da ByeDPI üzerinden bağlanabilir. Düz web proxy'si (HTTP) ve proxy istisna listeniz değiştirilmez. Roblox'un kendisi bu ayarı kullanmaz (onu Hızlı İşlemler'den başlatın), ama şifreyle girişteki güvenlik doğrulaması kullanır.",
                       "This option sets \(byedpiService.proxyAddress) as both the SOCKS proxy and the secure web proxy (HTTPS) on the active network service, so apps that don't support the proxy parameter but use the macOS proxy settings (such as Safari) can also connect through ByeDPI. The plain web proxy (HTTP) and your proxy bypass list are not changed. Roblox itself doesn't use this setting (start it from Quick actions), but the security check when signing in with a password does."))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(L("Sistem proxy yalnızca SplitWire/ByeDPI çalışırken güvenlidir. ByeDPI durdurulduğunda veya uygulamadan çıkıldığında otomatik olarak kapatılır (yönetici parolası istenir). Kapatılmazsa internet bağlantınız çalışmaz.",
                           "The system proxy is only safe while SplitWire/ByeDPI is running. It is turned off automatically when ByeDPI stops or you quit the app (your administrator password is required). If it stays on, your internet connection won't work."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                HStack {
                    Text(L("Sistem Proxy Durumu:", "System proxy status:"))
                        .fontWeight(.medium)
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(systemProxy.isOurProxyActive ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            let services = systemProxy.activeSummary
                            Text(systemProxy.isOurProxyActive
                                 ? L("Açık (\(services))", "On (\(services))")
                                 : L("Kapalı", "Off"))
                                .foregroundColor(systemProxy.isOurProxyActive ? .green : .red)
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Button(action: {
                        Task { await byedpiService.enableSystemProxy() }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(L("Aç", "Turn on"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    // Yalnızca SOCKS açıksa (v1.1.0'dan kalma) "Aç" HTTPS proxy'yi de ekler
                    .disabled(systemProxy.isBusy
                              || (systemProxy.isOurProxyActive && !systemProxy.hasIncompleteSetup)
                              || !byedpiService.isRunning || byedpiService.isProcessing)

                    Button(action: {
                        Task { await byedpiService.disableSystemProxy() }
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text(L("Kapat", "Turn off"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(systemProxy.isBusy || !systemProxy.isOurProxyActive)
                }

                if !byedpiService.isRunning && !systemProxy.isOurProxyActive {
                    Text(L("Sistem proxy'yi açmak için önce ByeDPI'ı başlatın.",
                           "Start ByeDPI first to turn on the system proxy."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if systemProxy.hasIncompleteSetup {
                    Text(L("Sistem proxy'nin yalnızca bir kısmı açık (ör. önceki sürümden kalan yalnızca SOCKS ayarı). HTTPS proxy'yi de eklemek için ByeDPI çalışırken 'Aç'a basın.",
                           "Only part of the system proxy is on (e.g. a SOCKS-only setting left over from the previous version). Press 'Turn on' while ByeDPI is running to add the HTTPS proxy too."))
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if systemProxy.isBusy {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(L("İşlem yapılıyor...", "Working…"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            RobloxGuideNote()
                .padding(.horizontal)

            Button(L("Kapat", "Close")) {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 520)
        .onAppear {
            Task {
                await systemProxy.refresh()
                isLoading = false
            }
        }
    }
}

/// Roblox için kısa rehber (#13). ByeDPI sekmesinde ve Sistem Proxy sayfasında gösterilir.
/// Roblox (libcurl) macOS proxy ayarlarını kullanmaz ama HTTPS_PROXY ortam değişkenini okur;
/// bu yüzden Hızlı İşlemler'den başlatılmalıdır. Şifreyle girişteki güvenlik doğrulaması ise
/// macOS web görünümünde açılır ve yalnızca sistem proxy'sini kullanır.
struct RobloxGuideNote: View {
    /// Roblox kurulu ama Hızlı İşlemler'de değilse "Ekle" düğmesi gösterilir.
    var onAddRoblox: (() -> Void)?

    static let bundleIdentifier = KnownApps.robloxBundleID

    /// Kurulu Roblox uygulaması (bundle id veya /Applications/Roblox.app).
    static func installedRobloxURL() -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url
        }
        let fallback = URL(fileURLWithPath: "/Applications/Roblox.app")
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Roblox", systemImage: "gamecontroller")
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 3) {
                Text(L("1. Önce DNS'i düzeltin: Ağ Ayarları'ndan 1.1.1.1 veya şifreli DNS (DoH) profili.",
                       "1. Fix DNS first: 1.1.1.1 or the encrypted DNS (DoH) profile in the Network tab."))
                Text(L("2. Roblox'u Hızlı İşlemler'e ekleyin ve her zaman oradan başlatın. Açıksa SplitWire onu (menü çubuğundaki Roblox simgesiyle birlikte) kapatıp yeniden açar.",
                       "2. Add Roblox to Quick actions and always start it from there. If it is open, SplitWire quits it (together with the Roblox menu bar icon) and reopens it."))
                Text(L("3. Şifreyle giriş yaparken Sistem Proxy'yi de açın: Roblox güvenlik doğrulamasını macOS'un web görünümünde açar ve bu görünüm yalnızca sistem proxy'sini kullanır (kapalıyken \"Security\" ekranı boş kalır). Giriş yaptıktan sonra kapatabilirsiniz.",
                       "3. Turn on System proxy while signing in with a password: Roblox shows its security check in a macOS web view, which only uses the system proxy (otherwise the \"Security\" screen stays blank). You can turn it off after signing in."))
                Text(L("4. Oyunlara Roblox uygulamasının içinden girin. Roblox'u menü çubuğundan tamamen kapattıysanız tarayıcıdaki \"Oyna\" düğmesi onu proxy'siz açar; o zaman Roblox'u kapatıp Hızlı İşlemler'den yeniden açın.",
                       "4. Join games from inside the Roblox app. If you fully quit Roblox from the menu bar, the \"Play\" button in the browser opens it without the proxy; then quit Roblox and reopen it from Quick actions."))
            }
            if let onAddRoblox {
                Button(L("Roblox'u Hızlı İşlemler'e Ekle", "Add Roblox to Quick actions"), action: onAddRoblox)
                    .controlSize(.small)
            }
            Text(L("Yalnızca Roblox'un web ve giriş trafiği ByeDPI'dan geçer; oyun trafiği (UDP) doğrudan sunucuya gider, ping etkilenmez ve sunucu değiştirmek normal çalışır. İşe yaramazsa WireGuard sekmesini kullanın (ping daha yüksek olabilir).",
                   "Only Roblox's web and login traffic goes through ByeDPI; game traffic (UDP) goes straight to the server, so ping isn't affected and switching servers works normally. If it doesn't work, use the WireGuard tab (ping may be higher)."))
                .foregroundColor(.secondary)
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// ByeDPI çalışırken bağlantı testi ve teşhisi (#15): "ByeDPI çalışıyor ama Discord açılmıyor"
/// durumunu (DNS engeli, TLS 1.2'yi geçirmeyen yöntem) kullanıcıya gösterir.
struct ConnectionTestView: View {
    @ObservedObject var byedpiService: ByeDPIService
    @ObservedObject private var tester = ConnectionTester.shared
    @ObservedObject private var dns = DNSHealthChecker.shared

    /// Sonuçlar şu an çalışan argümanlara mı ait (yöntem değişince eski sonuç gösterilmez)?
    private var hasCurrentResults: Bool {
        !tester.results.isEmpty && tester.testedArgs == byedpiService.runningArgs
    }

    private var diagnosis: ConnectionDiagnosis {
        ConnectionDiagnosis.evaluate(tester.results, dnsPoisoned: tester.dnsPoisonedDuringTest)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L("Bağlantı testi:", "Connection test:"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if tester.isTesting {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }
                Button(hasCurrentResults ? L("Tekrar Test Et", "Test again") : L("Test Et", "Test")) {
                    Task { await byedpiService.runConnectionTest() }
                }
                .controlSize(.small)
                .disabled(tester.isTesting || byedpiService.isProcessing)
                .help(L("Discord, Discord'un güncelleme denetimi ve Roblox'a ByeDPI üzerinden bağlanmayı dener",
                        "Tries to connect to Discord, Discord's update check and Roblox through ByeDPI"))
            }

            if hasCurrentResults && !tester.isTesting {
                ForEach(tester.results) { result in
                    HStack(spacing: 6) {
                        Image(systemName: result.reachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.reachable ? .green : .red)
                        Text(result.check.title.resolved)
                    }
                    .font(.caption)
                    .help(result.detail)
                }
                Text(diagnosis.message(currentPreset: byedpiService.runningPreset ?? byedpiService.currentPreset).resolved)
                    .font(.caption)
                    .foregroundColor(diagnosis == .allReachable ? .secondary : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: dns.lastChecked) { _ in
            // DNS yeniden kontrol edildi (ör. 1.1.1.1'e geçildi): eski sonuçlar geçersiz, yeniden test et
            guard byedpiService.isRunning, !tester.isTesting, !tester.results.isEmpty else { return }
            Task { await byedpiService.runConnectionTest() }
        }
    }
}
