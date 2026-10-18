// =Добро и позитив= — оборачивает каждое отправленное сообщение в «=…=».
//
// Ловит Enter во всех программах. Если фокус в поле ввода и в нём есть текст,
// глотает Enter и вместо него печатает: ⌘↑ (в начало), «=», ⌘↓ (в конец), «=», Enter.
// Пробелы по краям сообщения стирает, чтобы «=» стояли вплотную.
// Нужен доступ «Универсальный доступ» (Accessibility).

import AppKit
import ApplicationServices
import ServiceManagement

/// Метка на своих событиях, чтобы перехватчик их пропускал.
private let syntheticMark: Int64 = 0x3D3D_3D3D

private enum Key {
    static let returnKey: CGKeyCode = 36
    static let keypadEnter: CGKeyCode = 76
    static let equals: CGKeyCode = 24
    static let up: CGKeyCode = 126
    static let down: CGKeyCode = 125
    static let backspace: CGKeyCode = 51
    static let forwardDelete: CGKeyCode = 117
}

/// Программы, где Enter — не «отправить сообщение»: терминалы и редакторы кода.
private let excludedBundleIDs: Set<String> = [
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "dev.warp.Warp-Stable",
    "com.mitchellh.ghostty",
    "net.kovidgoyal.kitty",
    "io.alacritty",
    "com.github.wez.wezterm",
    "com.microsoft.VSCode",
    "com.todesktop.230313mzl4w4u92", // Cursor
    "dev.zed.Zed",
    "com.apple.dt.Xcode",
    "com.sublimetext.4",
]

private func isExcluded(_ bundleID: String) -> Bool {
    excludedBundleIDs.contains(bundleID) || bundleID.hasPrefix("com.jetbrains.")
}

// MARK: - Поле ввода

private enum Focus {
    private static let systemWide: AXUIElement = {
        let element = AXUIElementCreateSystemWide()
        // Перехватчик ждёт ответа синхронно — не даём зависшей программе его подвесить.
        AXUIElementSetMessagingTimeout(element, 0.25)
        return element
    }()

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    /// Сколько пробелов стоит в начале и в конце сообщения:
    /// их убираем, чтобы «=» встали вплотную к тексту.
    struct Edges {
        var leading = 0
        var trailing = 0
    }

    /// Оборачивать ли сообщение, которое сейчас отправят Enter-ом; nil — не оборачивать.
    static func edgesToWrap() -> Edges? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid() else { return nil }
        if let id = app.bundleIdentifier, isExcluded(id) { return nil }

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement

        let role = string(element, kAXRoleAttribute)
        guard role == kAXTextAreaRole || role == kAXTextFieldRole else { return nil }
        let subrole = string(element, kAXSubroleAttribute)
        if subrole == kAXSearchFieldSubrole || subrole == kAXSecureTextFieldSubrole { return nil }

        // Текст поля читается не везде; если прочитать не вышло — всё равно оборачиваем.
        guard let value = string(element, kAXValueAttribute) else { return Edges() }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if text.count >= 2, text.hasPrefix("="), text.hasSuffix("=") { return nil }

        // Только пробелы: невидимый перенос в конце поля (Slack, браузер) стирать нельзя,
        // иначе Backspace съест последнюю букву.
        let blank = { (c: Character) in c == " " || c == "\t" || c == "\u{00A0}" }
        return Edges(leading: value.prefix(while: blank).count,
                     trailing: value.reversed().prefix(while: blank).count)
    }

    /// Electron-приложения (Slack, Discord, WhatsApp и др.) отдают дерево
    /// доступности, только если их об этом попросить.
    static func enableAccessibility(for app: NSRunningApplication) {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }
}

// MARK: - Печать

private enum Typist {
    private static let queue = DispatchQueue(label: "dobroandpozitiv.typist", qos: .userInteractive)

    private static func post(_ code: CGKeyCode, flags: CGEventFlags = [], text: String? = nil) {
        let source = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { continue }
            event.flags = flags
            if let text {
                let units = Array(text.utf16)
                event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            }
            event.setIntegerValueField(.eventSourceUserData, value: syntheticMark)
            event.post(tap: .cghidEventTap)
        }
        usleep(12_000)
    }

    static func wrapAndSend(enter: CGKeyCode, edges: Focus.Edges) {
        queue.async {
            post(Key.up, flags: .maskCommand)
            for _ in 0..<edges.leading { post(Key.forwardDelete) }
            post(Key.equals, text: "=")
            post(Key.down, flags: .maskCommand)
            for _ in 0..<edges.trailing { post(Key.backspace) }
            post(Key.equals, text: "=")
            post(enter)
        }
    }
}

// MARK: - Перехват клавиатуры

private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                         refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)
    let app = AppDelegate.shared!

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        app.reenableTap()
        return pass
    }
    guard type == .keyDown, app.isOn,
          event.getIntegerValueField(.eventSourceUserData) != syntheticMark,
          event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return pass }

    let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    guard code == Key.returnKey || code == Key.keypadEnter else { return pass }
    // Shift+Enter — перенос строки, ⌘/⌥/⌃+Enter — что-то своё: не трогаем.
    let modifiers: CGEventFlags = [.maskShift, .maskCommand, .maskAlternate, .maskControl]
    guard event.flags.intersection(modifiers).isEmpty else { return pass }
    guard let edges = Focus.edgesToWrap() else { return pass }

    Typist.wrapAndSend(enter: code, edges: edges)
    return nil
}

// MARK: - Строка меню

/// Значок «=👍=»: шаблон, macOS сама красит его под светлую и тёмную строку меню.
private func menuIcon() -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
    let thumb = NSImage(systemSymbolName: "hand.thumbsup.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
    let bar: CGFloat = 6, gap: CGFloat = 2, height: CGFloat = 18
    let size = NSSize(width: bar * 2 + gap * 2 + thumb.size.width, height: height)
    let image = NSImage(size: size, flipped: false) { _ in
        NSColor.black.setFill()
        for x in [0, size.width - bar] {
            NSRect(x: x, y: 6.5, width: bar, height: 1.5).fill()
            NSRect(x: x, y: 10, width: bar, height: 1.5).fill()
        }
        thumb.draw(in: NSRect(x: bar + gap, y: (height - thumb.size.height) / 2,
                              width: thumb.size.width, height: thumb.size.height))
        return true
    }
    image.isTemplate = true
    return image
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!

    private let defaults = UserDefaults.standard
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let toggleItem = NSMenuItem(title: "Добро и позитив", action: #selector(toggle), keyEquivalent: "")
    private let accessItem = NSMenuItem(title: "Дать доступ…", action: #selector(openAccessSettings), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Запускать при входе", action: #selector(toggleLogin), keyEquivalent: "")
    private var tap: CFMachPort?
    private var permissionTimer: Timer?

    private(set) var isOn: Bool {
        get { defaults.object(forKey: "isOn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "isOn"); refresh() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        statusItem.button?.image = menuIcon()

        let menu = NSMenu()
        menu.autoenablesItems = false
        for item in [toggleItem, accessItem, loginItem] { item.target = self }
        menu.addItem(toggleItem)
        menu.addItem(accessItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        if let front = NSWorkspace.shared.frontmostApplication { Focus.enableAccessibility(for: front) }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                self?.startTapIfTrusted()
            }
        }
        startTapIfTrusted()
        refresh()
    }

    private func startTapIfTrusted() {
        guard tap == nil, AXIsProcessTrusted() else { refresh(); return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: handleEvent, userInfo: nil) else { refresh(); return }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        permissionTimer?.invalidate()
        permissionTimer = nil
        refresh()
    }

    func reenableTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private func refresh() {
        let working = isOn && tap != nil
        statusItem.button?.appearsDisabled = !working
        statusItem.button?.toolTip = working ? "=Добро и позитив= включено" : "=Добро и позитив= выключено"
        toggleItem.state = isOn ? .on : .off
        accessItem.isHidden = tap != nil
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggle() { isOn.toggle() }

    @objc private func appActivated(_ note: Notification) {
        if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            Focus.enableAccessibility(for: app)
        }
    }

    @objc private func openAccessSettings() {
        let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        NSWorkspace.shared.open(URL(string: url)!)
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
        refresh()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
