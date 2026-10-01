import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()

            // Tab View
            TabView(selection: $appState.selectedTab) {
                WireGuardView()
                    .tabItem {
                        Label("WireGuard", systemImage: "network")
                    }
                    .tag(0)

                ByeDPIView()
                    .tabItem {
                        Label("ByeDPI", systemImage: "shield.checkered")
                    }
                    .tag(1)

                NetworkConfigView()
                    .tabItem {
                        Label(L("Ağ Ayarları", "Network"), systemImage: "gearshape")
                    }
                    .tag(2)

                AboutView()
                    .tabItem {
                        Label(L("Hakkında", "About"), systemImage: "info.circle")
                    }
                    .tag(3)
            }
            .padding()

            // Status Bar
            StatusBarView()
        }
        // Dil değişince (#8) tüm pencere ağacı yeniden kurulur; L(...) metinleri yeniden okunur.
        // Görünümler kalıcı durumu tutmaz: servisler uygulama düzeyindeki paylaşılan örneklerdir,
        // seçili sekme AppState'te saklanır.
        .id(appState.selectedLanguage)
        .environment(\.locale, appState.selectedLanguage.locale)
        .preferredColorScheme(appState.isDarkMode ? .dark : .light)
    }
}

struct HeaderView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            // Logo and Title
            VStack(alignment: .leading, spacing: 4) {
                Text("SplitWire-Turkey")
                    .font(.title)
                    .fontWeight(.bold)
                Text(L("macOS için", "for macOS"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Dil seçimi (#8)
            Picker(L("Dil", "Language"), selection: $appState.selectedLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 120)
            .help(L("Arayüz dili", "Interface language"))

            // Dock simgesini gizle (#6) — uygulama menü çubuğunda çalışmaya devam eder
            Toggle(L("Dock simgesini gizle", "Hide Dock icon"), isOn: $appState.hideDockIcon)
                .toggleStyle(.checkbox)
                .help(L(
                    "Dock simgesini gizler. Uygulamaya menü çubuğundaki kalkan simgesinden erişebilirsiniz.",
                    "Hides the Dock icon. You can still open the app from the shield icon in the menu bar."
                ))

            // Dark Mode Toggle
            Toggle(L("Koyu mod", "Dark mode"), isOn: $appState.isDarkMode)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(L("Koyu mod", "Dark mode"))
                .onChange(of: appState.isDarkMode) { _ in
                    appState.saveSettings()
                }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct StatusBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            if appState.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Text(appState.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
