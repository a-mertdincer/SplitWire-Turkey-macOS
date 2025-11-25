import SwiftUI

@main
struct SplitWireTurkeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var menuBarService = MenuBarService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(menuBarService)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    menuBarService.setup()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("SplitWire-Turkey Hakkında") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "SplitWire-Turkey",
                            NSApplication.AboutPanelOptionKey.applicationVersion: "1.0",
                            NSApplication.AboutPanelOptionKey.version: "macOS Edition",
                            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2025 Çağrı Taşkın"
                        ]
                    )
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if user has chosen to hide the admin alert
        let hideAdminAlert = UserDefaults.standard.bool(forKey: "hideAdminAlert")

        // Check for admin privileges on launch
        if !hasAdminPrivileges() && !hideAdminAlert {
            showAdminRequiredAlert()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func hasAdminPrivileges() -> Bool {
        return geteuid() == 0
    }

    private func showAdminRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Yönetici Yetkileri Gerekli"
        alert.informativeText = "Bu uygulama ağ yapılandırması değişiklikleri yapmak için yönetici yetkileri gerektirir. Bazı özellikler çalışmayabilir."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Tamam")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Tekrar gösterme"

        alert.runModal()

        // Save the "don't show again" preference if checked
        if alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: "hideAdminAlert")
        }
    }
}
