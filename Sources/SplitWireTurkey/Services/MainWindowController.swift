import SwiftUI
import AppKit

/// Ana pencereyi (SwiftUI `Window(id: "main")`) her durumda geri getirir —
/// kullanıcı pencereyi kapatmış olsa ve uygulama Dock'ta görünmese bile.
@MainActor
final class MainWindowController {
    static let shared = MainWindowController()
    static let windowID = "main"
    /// Pencere menüsündeki "Ana Pencereyi Göster" komutunun kısayolu (⌘0).
    /// Yedek yol menü öğesini başlığa (dile bağlı) göre değil bu kısayola göre bulur.
    static let showMenuKeyEquivalent = "0"

    /// Sahneden yakalanan `openWindow` eylemi (ilk pencere görünümünde kaydedilir).
    var openWindowAction: OpenWindowAction?

    private init() {}

    /// Uygulamayı öne getirir ve ana pencereyi gösterir/oluşturur.
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = existingMainWindow(), window.isVisible || window.isMiniaturized {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else if let openWindowAction {
            openWindowAction(id: Self.windowID)
        } else if let item = findShowMenuItem(in: NSApp.windowsMenu) ?? findShowMenuItem(in: NSApp.mainMenu),
                  let menu = item.menu {
            // Yedek: Pencere menüsündeki SwiftUI komutu (⌘0)
            let index = menu.index(of: item)
            if index >= 0 { menu.performActionForItem(at: index) }
        }
        // Accessory (Dock'suz) modda da pencerenin öne gelmesi için tekrar etkinleştir
        DispatchQueue.main.async {
            self.bringToFrontIfVisible()
        }
    }

    /// Ana pencere görünürse öne getirir (Dock simgesi değişiminden sonra).
    func bringToFrontIfVisible() {
        guard let window = existingMainWindow(), window.isVisible else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func existingMainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            guard let id = window.identifier?.rawValue else { return false }
            return id == Self.windowID || id.hasPrefix(Self.windowID + "-")
        }
    }

    /// "Ana Pencereyi Göster" menü öğesini kısayoluna (⌘0) göre bulur; başlık dile göre değiştiği için kullanılmaz.
    private func findShowMenuItem(in menu: NSMenu?) -> NSMenuItem? {
        guard let menu else { return nil }
        for item in menu.items {
            let modifiers = item.keyEquivalentModifierMask.intersection(.deviceIndependentFlagsMask)
            if item.keyEquivalent == Self.showMenuKeyEquivalent, modifiers == .command, item.action != nil {
                return item
            }
            if let found = findShowMenuItem(in: item.submenu) { return found }
        }
        return nil
    }
}

/// Dock simgesini gizleme/gösterme (#6).
@MainActor
enum DockIconController {
    static let defaultsKey = "hideDockIcon"

    static func apply(hidden: Bool, reactivate: Bool) {
        let policy: NSApplication.ActivationPolicy = hidden ? .accessory : .regular
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        guard reactivate else { return }
        // .regular'a dönüşte Dock simgesi ve menü çubuğunun düzgün görünmesi için yeniden etkinleştir
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            MainWindowController.shared.bringToFrontIfVisible()
        }
    }
}
