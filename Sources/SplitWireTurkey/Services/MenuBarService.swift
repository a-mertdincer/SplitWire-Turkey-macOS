import Foundation
import AppKit
import Combine

/// Menü çubuğu (NSStatusItem) arayüzü.
///
/// Kendi süreç/preset durumu YOKTUR: `ByeDPIService`'i Combine ile izler ve
/// tüm işlemler için onun metodlarını çağırır (#12).
@MainActor
final class MenuBarService: NSObject, ObservableObject, NSMenuDelegate {
    private let byedpi: ByeDPIService
    private let systemProxy: SystemProxyService
    private let appState: AppState

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()
    /// Menü açıkken yeniden kurma ertelenir (açık alt menü / ipucu kapanmasın).
    private var isMenuOpen = false
    private var needsRebuild = false

    init(byedpi: ByeDPIService, systemProxy: SystemProxyService, appState: AppState) {
        self.byedpi = byedpi
        self.systemProxy = systemProxy
        self.appState = appState
        super.init()
    }

    /// Menü çubuğu öğesini oluşturur (uygulama açılışında bir kez).
    func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu

        rebuild()

        // Servisteki her değişiklikte menüyü ve simgeyi yenile.
        // objectWillChange değişiklikten ÖNCE yayınlanır; ana kuyrukta ertelenerek yeni değerler okunur.
        byedpi.objectWillChange
            .merge(with: systemProxy.objectWillChange, appState.objectWillChange)
            .debounce(for: .milliseconds(30), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildOrDefer()
            }
            .store(in: &cancellables)

        // Dil değişince (#8) tüm başlıkları yeniden üret
        NotificationCenter.default.publisher(for: .appLanguageDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuild()
            }
            .store(in: &cancellables)
    }

    // MARK: - NSMenuDelegate

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            rebuild()
        }
    }

    nonisolated func menuWillOpen(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            if menu === self.menu { isMenuOpen = true }
        }
    }

    nonisolated func menuDidClose(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            guard menu === self.menu else { return }
            isMenuOpen = false
            if needsRebuild {
                needsRebuild = false
                rebuildMenu()
            }
        }
    }

    // MARK: - Menü

    private func rebuild() {
        updateStatusIcon()
        rebuildMenu()
    }

    /// Menü açıkken öğeleri silip yeniden eklemek açık alt menüyü kapatır; kapanınca yeniden kurulur
    /// (`menuNeedsUpdate` her açılışta zaten tazeler).
    private func rebuildOrDefer() {
        updateStatusIcon()
        if isMenuOpen {
            needsRebuild = true
        } else {
            rebuildMenu()
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let iconName = byedpi.isRunning ? "shield.checkered" : "shield.slash"
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "ByeDPI")
        image?.isTemplate = true
        button.image = image
        button.toolTip = byedpi.isRunning
            ? L("ByeDPI çalışıyor (\(byedpi.proxyAddress))", "ByeDPI is running (\(byedpi.proxyAddress))")
            : L("ByeDPI durduruldu", "ByeDPI is stopped")
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        // Sistem proxy parola penceresi açıkken de Başlat/Durdur/preset devre dışı (#14 yarışı)
        let busy = byedpi.isProcessing || systemProxy.isBusy

        // Durum
        let statusTitle: String
        if byedpi.isProcessing {
            statusTitle = L("ByeDPI: İşlem yapılıyor…", "ByeDPI: Working…")
        } else if byedpi.isRunning {
            statusTitle = byedpi.isExternallyStarted
                ? L("ByeDPI: Çalışıyor (harici)", "ByeDPI: Running (external)")
                : L("ByeDPI: Çalışıyor", "ByeDPI: Running")
        } else {
            statusTitle = L("ByeDPI: Durduruldu", "ByeDPI: Stopped")
        }
        let statusLine = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        statusLine.image = createCircleImage(color: byedpi.isRunning ? .systemGreen : .systemRed)
        menu.addItem(statusLine)

        if byedpi.isRunning {
            let presetText = byedpi.runningPreset.map(presetDisplayName) ?? L("harici", "external")
            let runningLine = NSMenuItem(
                title: L("Çalışan yöntem: \(presetText)", "Active method: \(presetText)"),
                action: nil, keyEquivalent: ""
            )
            runningLine.isEnabled = false
            if let args = byedpi.runningArgs {
                runningLine.toolTip = args
            }
            menu.addItem(runningLine)

            if byedpi.isExposedToNetwork {
                let exposedLine = NSMenuItem(title: L("⚠︎ Tüm ağ arayüzlerinde dinliyor (ağınıza açık)",
                                                      "⚠︎ Listening on all network interfaces (exposed)"),
                                             action: nil, keyEquivalent: "")
                exposedLine.isEnabled = false
                exposedLine.toolTip = ByeDPIService.exposedWarning.resolved
                exposedLine.image = createCircleImage(color: .systemOrange)
                menu.addItem(exposedLine)
            }
        }

        menu.addItem(.separator())

        // Başlat / Durdur
        if byedpi.isRunning {
            menu.addItem(makeItem(L("ByeDPI'ı Durdur", "Stop ByeDPI"), #selector(stopByeDPI), key: "s", enabled: !busy))
        } else {
            menu.addItem(makeItem(L("ByeDPI'ı Başlat", "Start ByeDPI"), #selector(startByeDPI), key: "b", enabled: !busy))
        }
        let killItem = makeItem(L("Tümünü Zorla Kapat", "Force stop all"), #selector(killAllProcesses), key: "k", enabled: !busy)
        killItem.toolTip = L(
            "Tüm ciadpi süreçlerini sonlandırır ve gerekirse sistem proxy'yi kapatır.",
            "Kills every ciadpi process and turns off the system proxy if needed."
        )
        menu.addItem(killItem)

        menu.addItem(.separator())

        if byedpi.isRunning {
            menu.addItem(makeItem(
                L("SOCKS5: \(byedpi.proxyAddress) (Kopyala)", "SOCKS5: \(byedpi.proxyAddress) (copy)"),
                #selector(copyProxyAddress)
            ))
        }

        // Sistem proxy durumu
        if systemProxy.isOurProxyActive {
            let proxyLine = NSMenuItem(title: L("Sistem Proxy: Açık", "System proxy: on"), action: nil, keyEquivalent: "")
            proxyLine.isEnabled = false
            proxyLine.image = createCircleImage(color: byedpi.isRunning ? .systemGreen : .systemOrange)
            menu.addItem(proxyLine)
            menu.addItem(makeItem(
                L("Sistem Proxy'yi Kapat", "Turn off system proxy"),
                #selector(disableSystemProxy),
                enabled: !systemProxy.isBusy
            ))
        }

        // Preset alt menüsü (tablo sırasıyla)
        let presetMenu = NSMenu()
        presetMenu.autoenablesItems = false
        for preset in byedpi.presets {
            let item = NSMenuItem(title: presetDisplayName(preset.id), action: #selector(selectPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.id
            item.state = preset.id == byedpi.currentPreset ? .on : .off
            let custom = byedpi.customArgs.trimmingCharacters(in: .whitespacesAndNewlines)
            // Boş Custom çalışan ByeDPI'ı yeniden başlatamaz; pencereden düzenlenmeli
            item.isEnabled = !busy && !(preset.isCustom && custom.isEmpty && byedpi.isRunning)
            if preset.isCustom {
                item.toolTip = custom.isEmpty
                    ? L("Özel parametreler boş — ana pencereden düzenleyin", "Custom arguments are empty — edit them in the main window")
                    : custom
            } else {
                item.toolTip = preset.args
            }
            presetMenu.addItem(item)
        }
        let currentPresetName = presetDisplayName(byedpi.currentPreset)
        let presetMenuItem = NSMenuItem(
            title: L("DPI Yöntemi: \(currentPresetName)", "DPI method: \(currentPresetName)"),
            action: nil, keyEquivalent: ""
        )
        presetMenuItem.submenu = presetMenu
        presetMenuItem.isEnabled = !busy
        menu.addItem(presetMenuItem)

        menu.addItem(.separator())

        menu.addItem(makeItem(MainWindowController.localizedShowMenuTitle, #selector(showMainWindow), key: "o"))

        let dockItem = makeItem(L("Dock simgesini gizle", "Hide Dock icon"), #selector(toggleDockIcon))
        dockItem.state = appState.hideDockIcon ? .on : .off
        menu.addItem(dockItem)

        menu.addItem(.separator())

        menu.addItem(makeItem(L("Çıkış", "Quit"), #selector(quitApp), key: "q"))
    }

    /// Preset kimliği (kalıcı, çevrilmez) → menüde gösterilen ad.
    private func presetDisplayName(_ id: String) -> String {
        ByeDPIPresets.preset(id: id)?.name ?? id
    }

    private func makeItem(_ title: String, _ action: Selector, key: String = "", enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.isEnabled = enabled
        return item
    }

    private func createCircleImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 10, height: 10)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Eylemler

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let presetID = sender.representedObject as? String else { return }
        byedpi.selectPreset(presetID)
    }

    @objc private func startByeDPI() {
        Task { await byedpi.start() }
    }

    @objc private func stopByeDPI() {
        Task { await byedpi.stop() }
    }

    @objc private func killAllProcesses() {
        Task { await byedpi.killAllProcesses() }
    }

    @objc private func disableSystemProxy() {
        Task { await byedpi.disableSystemProxy() }
    }

    @objc private func copyProxyAddress() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("socks5://\(byedpi.proxyAddress)", forType: .string)
    }

    @objc private func showMainWindow() {
        MainWindowController.shared.show()
    }

    @objc private func toggleDockIcon() {
        appState.hideDockIcon.toggle()
    }

    @objc private func quitApp() {
        // Sistem proxy kapatma ve ciadpi durdurma AppDelegate.applicationShouldTerminate içinde
        NSApp.terminate(nil)
    }
}
