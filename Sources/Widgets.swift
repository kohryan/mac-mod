import AppKit
import SwiftUI
import Network

let accent = Color(red: 0.64, green: 0.90, blue: 0.94)
let muted = Color.white.opacity(0.58)

final class DashboardModel: ObservableObject {
    @Published var now = Date()
    @Published var cpu: Double?
    @Published var cpuHistory: [Double] = []
    @Published var memory: (used: Double, total: Double)?
    @Published var battery: Battery?
    @Published var wifi = WiFiStatus(powered: true, connected: false, name: nil, signal: nil)
    @Published var focus = FocusSession()
    @Published var message = "CLICK A CONTROL TO BEGIN"
    private let reader = MetricsReader()
    private var previous: CPUTicks?
    private var timer: Timer?
    private var ticks = 0
    private let wifiMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private var wifiConnected = false

    init() {
        previous = reader.cpu()
        memory = reader.memory()
        battery = reader.battery()
        wifi = reader.wifi(connected: false)
        wifiMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                self.wifiConnected = path.status == .satisfied
                self.wifi = self.reader.wifi(connected: self.wifiConnected)
            }
        }
        wifiMonitor.start(queue: DispatchQueue(label: "local.kohryan.mac-mod.wifi"))
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func tick() {
        now = Date()
        if focus.tick(at: now) { NSSound.beep() }
        ticks += 1
        if let current = reader.cpu() {
            cpu = previous.flatMap { current.usage(since: $0) }
            previous = current
            if let cpu { cpuHistory = Array((cpuHistory + [cpu]).suffix(60)) }
        } else { cpu = nil }
        if ticks % 2 == 0 { memory = reader.memory() }
        if ticks % 10 == 0 { battery = reader.battery(); wifi = reader.wifi(connected: wifiConnected) }
    }

    func launch(_ identifier: String, name: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            message = "\(name.uppercased()) IS NOT INSTALLED"
            return
        }
        launch(url, name: name)
    }

    func launch(_ url: URL, name: String) {
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            DispatchQueue.main.async { self.message = error == nil ? "\(name.uppercased()) OPENED" : "COULD NOT OPEN \(name.uppercased())" }
        }
    }
}

func micro(_ text: String) -> some View {
    Text(text).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.3)
}

struct ConsoleButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.white.opacity(configuration.isPressed ? 0.20 : 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.15)))
            .foregroundStyle(accent)
    }
}

struct ConsoleView: View {
    @ObservedObject var model: DashboardModel
    private var time: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Jakarta")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: model.now)
    }
    private var date: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Jakarta")
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEE, dd MMM yyyy"
        return formatter.string(from: model.now).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack { micro("PILOT / KOHRYAN").foregroundStyle(accent); Spacer(); Image(systemName: "circle.grid.2x2").foregroundStyle(muted) }
            Text(time).font(.system(size: 43, weight: .ultraLight, design: .monospaced)).monospacedDigit()
            micro("\(date) / WIB").foregroundStyle(muted)
            Divider().overlay(Color.white.opacity(0.08))
            HStack { micro("FOCUS SESSION").foregroundStyle(muted); Spacer(); micro(model.focus.complete ? "COMPLETE" : model.focus.isPaused ? "PAUSED" : model.focus.deadline == nil ? "STANDBY" : "RUNNING").foregroundStyle(accent) }
            HStack(alignment: .center) {
                let seconds = model.focus.seconds(at: model.now)
                Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                    .font(.system(size: 38, weight: .light, design: .monospaced)).monospacedDigit()
                Spacer()
                Image(systemName: model.focus.deadline == nil ? "timer" : "hourglass").font(.system(size: 24, weight: .ultraLight)).foregroundStyle(accent)
            }
            HStack(spacing: 8) {
                Button { model.now = Date(); model.focus.toggle(at: model.now) } label: {
                    Label(model.focus.deadline == nil ? (model.focus.isPaused ? "Resume" : "Start") : "Pause", systemImage: model.focus.deadline == nil ? "play.fill" : "pause.fill")
                }.accessibilityIdentifier("focus-toggle")
                Button("Reset") { model.focus = FocusSession() }.accessibilityIdentifier("focus-reset")
            }.buttonStyle(ConsoleButton())
        }.padding(22).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(Color.white).preferredColorScheme(.dark)
    }
}

struct CalendarView: View {
    @ObservedObject var model: DashboardModel
    @State private var monthOffset = 0
    @State private var selection: Date?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
    private var month: Date { cockpitCalendar.date(byAdding: .month, value: monthOffset, to: model.now) ?? model.now }
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = cockpitCalendar
        formatter.timeZone = cockpitCalendar.timeZone
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month).uppercased()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                micro("CALENDAR").foregroundStyle(accent)
                Spacer()
                Button { monthOffset = 0; selection = nil } label: { Text("TODAY").font(.system(size: 8, design: .monospaced)) }.buttonStyle(.plain).foregroundStyle(muted).accessibilityLabel("Calendar Today")
                Button { model.launch("com.apple.iCal", name: "Calendar") } label: { Image(systemName: "arrow.up.right.square").font(.system(size: 10)) }.buttonStyle(.plain).foregroundStyle(muted).help("Open Calendar").accessibilityLabel("Open Calendar")
            }
            HStack {
                Text(monthTitle).font(.system(size: 12, weight: .medium, design: .monospaced)).tracking(1)
                Spacer()
                Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left").frame(width: 18, height: 20) }.accessibilityLabel("Previous month")
                Button { monthOffset += 1 } label: { Image(systemName: "chevron.right").frame(width: 18, height: 20) }.accessibilityLabel("Next month")
            }.buttonStyle(.plain).foregroundStyle(accent)
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                    Text(day).font(.system(size: 9, design: .monospaced)).foregroundStyle(muted).frame(height: 17)
                }
                ForEach(Array(calendarCells(for: month).enumerated()), id: \.offset) { _, date in
                    if let date {
                        let today = cockpitCalendar.isDate(date, inSameDayAs: model.now)
                        let selected = selection.map { cockpitCalendar.isDate(date, inSameDayAs: $0) } ?? false
                        Button { selection = date } label: {
                            Text("\(cockpitCalendar.component(.day, from: date))").font(.system(size: 11, weight: today ? .semibold : .regular, design: .monospaced))
                                .frame(maxWidth: .infinity).frame(height: 24)
                                .foregroundStyle(today ? Color.black : .white.opacity(0.85))
                                .background(Circle().fill(today ? accent : .clear))
                                .overlay(Circle().stroke(selected && !today ? accent.opacity(0.8) : .clear))
                        }.buttonStyle(.plain).accessibilityLabel(date.formatted(.dateTime.day().month(.wide).year()))
                    } else { Color.clear.frame(height: 24) }
                }
            }
        }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(Color.white).preferredColorScheme(.dark)
    }
}

struct Sparkline: Shape {
    var values: [Double]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        for (i, value) in values.enumerated() {
            let point = CGPoint(x: CGFloat(i) / CGFloat(values.count - 1) * rect.width, y: (1 - min(1, max(0, value))) * rect.height)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

struct TelemetryView: View {
    @ObservedObject var model: DashboardModel
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { micro("SYSTEM TELEMETRY"); Spacer(); Circle().fill(accent).frame(width: 4, height: 4); micro("LIVE").foregroundStyle(accent) }
            Divider().overlay(Color.white.opacity(0.08))
            HStack(alignment: .firstTextBaseline) {
                micro("CPU").foregroundStyle(muted); Spacer()
                Text(model.cpu.map { String(format: "%.0f%%", $0 * 100) } ?? "—").font(.system(size: 34, weight: .light, design: .monospaced)).monospacedDigit()
            }
            ZStack {
                VStack { Divider(); Spacer(); Divider(); Spacer(); Divider() }.opacity(0.15)
                Sparkline(values: model.cpuHistory).stroke(accent, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }.frame(height: 45)
            HStack { micro("60 S HISTORY"); Spacer(); micro("1 S SAMPLE") }.foregroundStyle(muted)
            Divider().overlay(Color.white.opacity(0.08))
            HStack { micro("RAM").foregroundStyle(muted); Spacer()
                if let memory = model.memory {
                    Text(String(format: "%.1f / %.0f GB", memory.used / 1073741824, memory.total / 1073741824)).font(.system(size: 18, weight: .light, design: .monospaced)).monospacedDigit()
                } else { Text("N/A") }
            }
            ProgressView(value: model.memory.map { $0.used / $0.total } ?? 0).tint(accent)
            micro("ACTIVE · WIRED · COMPRESSED").foregroundStyle(muted)
            Divider().overlay(Color.white.opacity(0.08))
            micro("NATIVE SENSORS / LOCAL ONLY").foregroundStyle(muted)
        }.padding(22).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(Color.white).preferredColorScheme(.dark)
    }
}

final class GlassPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(title: String, frame: NSRect, view: some View) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        self.title = title
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.wantsLayer = true
        container.layer?.cornerRadius = 20
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 0.75
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.20).cgColor
        let glass = NSVisualEffectView(frame: container.bounds)
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.appearance = NSAppearance(named: .darkAqua)
        glass.alphaValue = 0.72
        glass.autoresizingMask = [.width, .height]
        container.addSubview(glass)
        let content = NSHostingView(rootView: view)
        content.frame = container.bounds
        content.autoresizingMask = [.width, .height]
        container.addSubview(content)
        contentView = container
        setFrameAutosaveName("MacMod.glass-v2.\(title)")
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(self.frame) }) { setFrame(frame, display: false) }
        orderFrontRegardless()
    }
}
