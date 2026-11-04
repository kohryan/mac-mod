import AppKit
import SwiftUI

struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 23
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - radius), control: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct PrayerNotchView: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject var prayers: PrayerStore
    let hardwareWidth: CGFloat
    let headerHeight: CGFloat
    let hover: (Bool) -> Void
    let toggle: () -> Void

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
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: model.battery?.charging == true ? "battery.100percent.bolt" : "battery.100percent", variableValue: model.battery?.percent)
                        .font(.system(size: 18)).foregroundStyle(model.battery.map { $0.percent <= 0.2 ? Color.orange : accent } ?? muted)
                    Text(model.battery.map { "\(Int(($0.percent * 100).rounded()))%" } ?? "N/A")
                        .font(.system(size: 10, weight: .medium, design: .monospaced)).monospacedDigit()
                    Image(systemName: model.wifi.connected ? "wifi" : "wifi.slash", variableValue: model.wifi.connected ? model.wifi.signal : nil)
                        .font(.system(size: 12)).foregroundStyle(model.wifi.connected ? accent : muted).help(model.wifi.label)
                }
                if hardwareWidth > 0 {
                    Spacer(minLength: hardwareWidth + 10)
                } else {
                    Text(prayers.snapshot?.location.city ?? "Lokasi…").font(.system(size: 10)).foregroundStyle(muted).lineLimit(1)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars").foregroundStyle(accent)
                    if let next {
                        Text(next.name).font(.system(size: 11, weight: .medium))
                        Text(time(next)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(accent)
                    } else { Text(prayers.loading ? "Memuat…" : "Jadwal belum tersedia").font(.system(size: 10)).foregroundStyle(muted) }
                }
            }.padding(.horizontal, 18).frame(height: headerHeight)
                .contentShape(Rectangle()).onTapGesture(perform: toggle)
                .accessibilityElement(children: .combine).accessibilityLabel("Notch: \(prayers.snapshot?.location.city ?? "lokasi belum tersedia"), baterai \(model.battery.map { Int(($0.percent * 100).rounded()) } ?? 0) persen, \(model.wifi.label), \(next.map { "\($0.name) \(time($0))" } ?? "jadwal belum tersedia")")

            if prayers.expanded {
                VStack(alignment: .leading, spacing: 13) {
                    Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
                    HStack(alignment: .center) {
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
                        HStack(spacing: 8) {
                            ForEach(today.prayers) { prayer in
                                VStack(spacing: 8) {
                                    Text(prayer.name).font(.system(size: 10, weight: .medium))
                                    Text(time(prayer)).font(.system(size: 16, weight: .medium, design: .monospaced))
                                }.frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .foregroundStyle(prayer.id == next?.id ? accent : Color.white.opacity(0.76))
                                    .background(RoundedRectangle(cornerRadius: 11).fill(prayer.id == next?.id ? accent.opacity(0.12) : Color.white.opacity(0.035)))
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
                }.padding(.horizontal, 18).padding(.bottom, 16)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.black.opacity(0.97)).clipShape(NotchShape())
            .overlay(NotchShape().stroke(Color.white.opacity(0.10), lineWidth: 0.7))
            .foregroundStyle(Color.white).preferredColorScheme(.dark)
            .onHover(perform: hover)
    }
}

final class PrayerNotchPanel: NSPanel {
    private let model: DashboardModel
    private let prayers: PrayerStore
    private var closeTask: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(model: DashboardModel, prayers: PrayerStore) {
        self.model = model
        self.prayers = prayers
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        title = "Prayer Notch"
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        layout()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.layout() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.prayers.refresh(); self?.layout() })
        orderFrontRegardless()
    }

    private func layout() {
        guard let screen = NSScreen.screens.first else { return }
        let gap: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            gap = max(0, right.minX - left.maxX)
        } else { gap = 0 }
        let header = max(36, screen.safeAreaInsets.top)
        let width = min(screen.frame.width - 80, prayers.expanded ? max(560, gap + 320) : max(420, gap + 300))
        let height = prayers.expanded ? header + 181 : header
        let top = screen.safeAreaInsets.top > 0 ? screen.frame.maxY : screen.frame.maxY - NSStatusBar.system.thickness
        setFrame(NSRect(x: screen.frame.midX - width / 2, y: top - height, width: width, height: height), display: true)
        contentView = NSHostingView(rootView: PrayerNotchView(model: model, prayers: prayers, hardwareWidth: gap, headerHeight: header,
                                                             hover: { [weak self] inside in self?.hover(inside) },
                                                             toggle: { [weak self] in guard let self else { return }; self.setExpanded(!self.prayers.expanded) }))
    }

    private func hover(_ inside: Bool) {
        closeTask?.cancel()
        if inside { setExpanded(true) }
        else {
            let task = DispatchWorkItem { [weak self] in self?.setExpanded(false) }
            closeTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
        }
    }

    func setExpanded(_ value: Bool) {
        guard prayers.expanded != value else { return }
        prayers.expanded = value
        layout()
    }

    func show() { closeTask?.cancel(); setExpanded(true); makeKeyAndOrderFront(nil) }
}
