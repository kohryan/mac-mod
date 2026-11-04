import AppKit
import SwiftUI

struct PrayerNotchView: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject var prayers: PrayerStore
    private var next: Prayer? { prayers.snapshot?.next(after: model.now) }
    private var today: PrayerDay? { prayers.snapshot?.day(at: model.now) }

    private func time(_ prayer: Prayer) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = prayers.snapshot?.location.timeZone ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: prayer.time)
    }

    private var remaining: String {
        guard let next else { return "Jadwal berikutnya belum tersedia" }
        let minutes = max(1, Int(ceil(next.time.timeIntervalSince(model.now) / 60)))
        return minutes >= 60 ? "\(minutes / 60) jam \(minutes % 60) menit lagi" : "\(minutes) menit lagi"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                Image(systemName: model.battery?.charging == true ? "battery.100percent.bolt" : "battery.100percent", variableValue: model.battery?.percent)
                    .font(.system(size: 18)).foregroundStyle(model.battery.map { $0.percent <= 0.2 ? Color.orange : accent } ?? muted)
                Text(model.battery.map { "\(Int(($0.percent * 100).rounded()))%" } ?? "N/A")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Image(systemName: model.wifi.connected ? "wifi" : "wifi.slash", variableValue: model.wifi.connected ? model.wifi.signal : nil)
                    .foregroundStyle(model.wifi.connected ? accent : muted).help(model.wifi.label)
                Spacer()
                Image(systemName: "moon.stars").foregroundStyle(accent)
                if let next {
                    Text(next.name).font(.system(size: 11, weight: .medium))
                    Text(time(next)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(accent)
                } else { Text(prayers.loading ? "Memuat…" : "Jadwal belum tersedia").font(.system(size: 10)).foregroundStyle(muted) }
            }
            Divider().overlay(Color.white.opacity(0.10))
            HStack {
                Image(systemName: "location.fill").foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(prayers.snapshot.map { "\($0.location.city), \($0.location.region)" } ?? "Lokasi belum tersedia")
                        .font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text("Perkiraan IP · \(model.wifi.label)").font(.system(size: 9)).foregroundStyle(muted).lineLimit(1)
                }
                Spacer()
                Button { prayers.refresh(force: true) } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).disabled(prayers.loading).help("Perbarui lokasi dan jadwal").accessibilityLabel("Perbarui jadwal sholat")
            }
            if let today {
                HStack(spacing: 7) {
                    ForEach(today.prayers) { prayer in
                        VStack(spacing: 8) {
                            Text(prayer.name).font(.system(size: 10, weight: .medium))
                            Text(time(prayer)).font(.system(size: 15, weight: .medium, design: .monospaced))
                        }.frame(maxWidth: .infinity).padding(.vertical, 10)
                            .foregroundStyle(prayer.id == next?.id ? accent : Color.white.opacity(0.76))
                            .background(RoundedRectangle(cornerRadius: 10).fill(prayer.id == next?.id ? accent.opacity(0.12) : Color.white.opacity(0.035)))
                    }
                }
            } else {
                Text(prayers.loading ? "Mengambil jadwal sholat…" : "Jadwal hari ini belum tersedia.").font(.system(size: 12)).foregroundStyle(muted).frame(height: 55)
            }
            HStack {
                Text(prayers.error ?? remaining).lineLimit(1).foregroundStyle(prayers.error == nil ? muted : .orange)
                Spacer(minLength: 8)
                Link("AlAdhan · Kemenag 20", destination: URL(string: "https://aladhan.com/calculation-methods")!).foregroundStyle(muted)
            }.font(.system(size: 9))
        }.padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.black.opacity(0.97)).foregroundStyle(Color.white).preferredColorScheme(.dark)
    }
}

final class PrayerNotchController {
    private let popover = NSPopover()

    init(model: DashboardModel, prayers: PrayerStore) {
        let controller = NSViewController()
        controller.view = NSHostingView(rootView: PrayerNotchView(model: model, prayers: prayers))
        popover.contentViewController = controller
        popover.contentSize = NSSize(width: 460, height: 213)
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
    }

    func toggle(relativeTo button: NSView) {
        if popover.isShown { popover.performClose(nil) }
        else { show(relativeTo: button) }
    }

    func show(relativeTo button: NSView) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

final class CenteredEyePanel: NSPanel {
    let button = NSButton(frame: .zero)
    private var eyes: EyeStatusIcon?
    private var screenObserver: NSObjectProtocol?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(target: AnyObject, action: Selector) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        title = "MacMod Eyes"
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        button.title = ""
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .white
        button.appearance = NSAppearance(named: .darkAqua)
        button.setAccessibilityLabel("MacMod · Jadwal sholat")
        button.toolTip = "Klik untuk jadwal sholat"
        button.target = target
        button.action = action
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        contentView = button
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.black.cgColor
        button.layer?.cornerRadius = 7
        button.layer?.masksToBounds = true
        position()
        eyes = EyeStatusIcon(button: button)
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.position() }
        orderFrontRegardless()
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    private func position() {
        guard let screen = NSScreen.screens.first else { return }
        let height = max(NSStatusBar.system.thickness, screen.frame.maxY - screen.visibleFrame.maxY)
        setFrame(NSRect(x: screen.frame.midX - 18, y: screen.frame.maxY - height, width: 36, height: height), display: true)
    }
}

final class EyeStatusIcon {
    private weak var button: NSButton?
    private var timer: Timer?
    private var lastPose = ""

    init(button: NSButton) {
        self.button = button
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in self?.update() }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    deinit { timer?.invalidate() }

    private func update() {
        guard let button, let screen = button.window?.screen ?? NSScreen.main else { return }
        let pointer = NSEvent.mouseLocation
        let dx = Int((max(-1, min(1, (pointer.x - screen.frame.midX) / (screen.frame.width / 2))) * 2).rounded())
        let dy = Int((max(-1, min(1, (pointer.y - screen.frame.midY) / (screen.frame.height / 2))) * 1).rounded())
        let blink = Date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) < 0.16
        let pose = "\(dx),\(dy),\(blink)"
        guard pose != lastPose else { return }
        lastPose = pose
        let image = NSImage(size: NSSize(width: 30, height: 18), flipped: false) { _ in
            for x: CGFloat in [2, 18] {
                NSColor.black.setFill()
                if blink {
                    NSBezierPath(roundedRect: NSRect(x: x, y: 8, width: 10, height: 2), xRadius: 1, yRadius: 1).fill()
                } else {
                    NSBezierPath(roundedRect: NSRect(x: x, y: 3, width: 10, height: 12), xRadius: 5, yRadius: 5).fill()
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current?.compositingOperation = .clear
                    NSBezierPath(ovalIn: NSRect(x: x + 3 + CGFloat(dx), y: 6.5 + CGFloat(dy), width: 4, height: 5)).fill()
                    NSGraphicsContext.restoreGraphicsState()
                }
            }
            return true
        }
        image.isTemplate = true
        button.image = image
    }
}
