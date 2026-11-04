import AppKit
import SwiftUI
import ServiceManagement

let bundleID = "local.kohryan.mac-mod"
let stateDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/mac-mod")

struct WallpaperBackup: Codable {
    let display: UInt32
    let url: String?
}

func screenID(_ screen: NSScreen) -> UInt32 {
    (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
}

func setWallpaper(restore: Bool) throws {
    let manager = FileManager.default
    try manager.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
    let backup = stateDirectory.appendingPathComponent("wallpaper-backup.json")
    if !restore && !manager.fileExists(atPath: backup.path) {
        let records = NSScreen.screens.map { WallpaperBackup(display: screenID($0), url: NSWorkspace.shared.desktopImageURL(for: $0)?.absoluteString) }
        try JSONEncoder().encode(records).write(to: backup, options: .atomic)
        let store = manager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
        if manager.fileExists(atPath: store.path) {
            let savedStore = stateDirectory.appendingPathComponent("wallpaper-original.plist")
            if !manager.fileExists(atPath: savedStore.path) { try manager.copyItem(at: store, to: savedStore) }
        }
    }
    if restore {
        let records = try JSONDecoder().decode([WallpaperBackup].self, from: Data(contentsOf: backup))
        for screen in NSScreen.screens {
            guard let record = records.first(where: { $0.display == screenID(screen) }), let text = record.url, let url = URL(string: text) else {
                throw NSError(domain: bundleID, code: 1, userInfo: [NSLocalizedDescriptionKey: "Previous dynamic wallpaper has no image URL. Original settings are backed up in \(stateDirectory.path)."])
            }
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        }
    } else {
        guard let image = Bundle.main.url(forResource: "gundam-hangar", withExtension: "png") else { throw CocoaError(.fileNoSuchFile) }
        for screen in NSScreen.screens { try NSWorkspace.shared.setDesktopImageURL(image, for: screen, options: [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue]) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var panels: [GlassPanel] = []
    var eyePanel: CenteredEyePanel?
    let model = DashboardModel()
    let prayers = PrayerStore()
    var notch: PrayerNotchController?
    var statusMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let frame = NSScreen.screens.first?.visibleFrame else { return }
        let left = GlassPanel(title: "Pilot Console", frame: NSRect(x: frame.minX + 48, y: frame.maxY - 430, width: 300, height: 330), view: ConsoleView(model: model))
        let right = GlassPanel(title: "System Telemetry", frame: NSRect(x: frame.maxX - 332, y: frame.maxY - 455, width: 284, height: 360), view: TelemetryView(model: model))
        let calendar = GlassPanel(title: "Calendar", frame: NSRect(x: frame.minX + 48, y: frame.maxY - 738, width: 300, height: 290), view: CalendarView(model: model))
        panels = [left, right, calendar]
        notch = PrayerNotchController(model: model, prayers: prayers)
        let menu = NSMenu()
        for (title, action) in [("Show Prayer Notch", #selector(showNotch)), ("Show Pilot Console", #selector(showConsole)), ("Show System Telemetry", #selector(showTelemetry)), ("Show Calendar", #selector(showCalendar)), ("Start at Login", #selector(toggleLogin)), ("Apply Gundam Wallpaper", #selector(applyWallpaper)), ("Restore Previous Wallpaper", #selector(restoreWallpaper)), ("Quit MacMod", #selector(quit))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.delegate = self
        eyePanel = CenteredEyePanel(target: self, action: #selector(statusClicked(_:)))
        statusMenu = menu
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = menu.copy() as? NSMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
        if !FileManager.default.fileExists(atPath: stateDirectory.appendingPathComponent("wallpaper-applied").path) {
            applyWallpaper()
        }
        if !UserDefaults.standard.bool(forKey: "loginConfigured") {
            enableLogin()
        }
        left.makeKeyAndOrderFront(nil)
    }

    @objc func showConsole() { panels.first?.makeKeyAndOrderFront(nil) }
    @objc func showNotch() {
        guard let button = eyePanel?.button else { return }
        notch?.show(relativeTo: button)
    }
    @objc func statusClicked(_ sender: NSButton) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp, let menu = statusMenu {
            NSMenu.popUpContextMenu(menu, with: event, for: sender)
        } else { notch?.toggle(relativeTo: sender) }
    }
    @objc func showTelemetry() { panels[1].makeKeyAndOrderFront(nil) }
    @objc func showCalendar() { panels[2].makeKeyAndOrderFront(nil) }
    func menuWillOpen(_ menu: NSMenu) {
        menu.item(withTitle: "Start at Login")?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
    func enableLogin() {
        do {
            if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            UserDefaults.standard.set(true, forKey: "loginConfigured")
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { report(error) }
    }
    @objc func toggleLogin() {
        if SMAppService.mainApp.status == .enabled {
            do { try SMAppService.mainApp.unregister(); UserDefaults.standard.set(true, forKey: "loginConfigured") }
            catch { report(error) }
        } else { enableLogin() }
    }
    @objc func applyWallpaper() {
        do {
            try setWallpaper(restore: false)
            try Data().write(to: stateDirectory.appendingPathComponent("wallpaper-applied"))
            model.message = "WALLPAPER APPLIED"
        } catch { report(error) }
    }
    @objc func restoreWallpaper() {
        do {
            try setWallpaper(restore: true)
            model.message = "PREVIOUS WALLPAPER RESTORED"
        } catch { report(error) }
    }
    func report(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
}

if CommandLine.arguments.contains("--quit") {
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) { app.terminate() }
    exit(0)
}
if CommandLine.arguments.contains("--login-status") {
    print(SMAppService.mainApp.status == .enabled ? "enabled" : "status=\(SMAppService.mainApp.status.rawValue)")
    exit(0)
}
if CommandLine.arguments.contains("--disable-login") {
    do {
        if SMAppService.mainApp.status != .notRegistered { try SMAppService.mainApp.unregister() }
        UserDefaults.standard.set(false, forKey: "loginConfigured")
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
    exit(0)
}
if CommandLine.arguments.contains("--restore-wallpaper") {
    do { try setWallpaper(restore: true) } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
    exit(0)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
