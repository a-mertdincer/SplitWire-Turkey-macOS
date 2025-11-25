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
                        Label("Ağ Ayarları", systemImage: "gearshape")
                    }
                    .tag(2)

                AboutView()
                    .tabItem {
                        Label("Hakkında", systemImage: "info.circle")
                    }
                    .tag(3)
            }
            .padding()

            // Status Bar
            StatusBarView()
        }
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
                Text("macOS Edition")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Language Picker
            Picker("", selection: $appState.selectedLanguage) {
                ForEach(AppState.Language.allCases, id: \.self) { lang in
                    Text(lang.rawValue).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)

            // Dark Mode Toggle
            Toggle("", isOn: $appState.isDarkMode)
                .toggleStyle(.switch)
                .labelsHidden()
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
