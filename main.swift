import SwiftUI
import CoreAudio
import AudioToolbox
import AVFoundation

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var n: UInt64 = 0; Scanner(string: s).scanHexInt64(&n)
        self.init(red: Double((n >> 16) & 0xFF)/255, green: Double((n >> 8) & 0xFF)/255, blue: Double(n & 0xFF)/255)
    }
}

// MARK: - Models

struct AudioDevice: Identifiable {
    let id: AudioDeviceID
    let name: String
    let isInput: Bool
    let isOutput: Bool
}

struct AudioApp: Identifiable, Hashable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    var volume: Float = 0.5
    var isMuted: Bool = false
}

enum ViewMode { case controls, appMixer, settings }
enum AppTheme: String, CaseIterable { case system, light, dark }

// MARK: - CoreAudio Helpers

enum AudioHelper {
    static func getDefaultDevice(isInput: Bool) -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    static func getVolume(device: AudioDeviceID, isInput: Bool) -> Float {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume)
        if status != noErr { return 0 }
        return volume
    }

    static func setVolume(device: AudioDeviceID, volume: Float, isInput: Bool) {
        var vol = volume
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(device, &address, 0, nil, size, &vol)
    }

    static func getMute(device: AudioDeviceID, isInput: Bool) -> Bool {
        var mute: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &mute)
        return mute != 0
    }

    static func setMute(device: AudioDeviceID, muted: Bool, isInput: Bool) {
        var mute: UInt32 = muted ? 1 : 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(device, &address, 0, nil, size, &mute)
    }

    static func getAllDevices() -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)

        return deviceIDs.compactMap { id -> AudioDevice? in
            let name = getDeviceName(id)
            guard !name.isEmpty else { return nil }
            let hasOutput = hasStreams(id, isInput: false)
            let hasInput = hasStreams(id, isInput: true)
            guard hasOutput || hasInput else { return nil }
            return AudioDevice(id: id, name: name, isInput: hasInput, isOutput: hasOutput)
        }
    }

    static func getDeviceName(_ id: AudioDeviceID) -> String {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name)
        return name as String
    }

    static func hasStreams(_ id: AudioDeviceID, isInput: Bool) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size)
        return size > 0
    }

    static func setDefaultDevice(_ id: AudioDeviceID, isInput: Bool) {
        var deviceID = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &deviceID)
    }

    static func getAudioApps() -> [AudioApp] {
        let workspace = NSWorkspace.shared
        return workspace.runningApplications.compactMap { app -> AudioApp? in
            guard app.activationPolicy == .regular,
                  let name = app.localizedName,
                  !name.isEmpty else { return nil }
            return AudioApp(
                id: app.processIdentifier,
                name: name,
                icon: app.icon,
                volume: 0.5,
                isMuted: false
            )
        }.sorted { $0.name < $1.name }
    }
}

// MARK: - Storage

final class AppVolumeStorage {
    static let shared = AppVolumeStorage()
    private init() {}

    private var storagePath: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VolPerApp")
    }
    private var volumesFile: URL { storagePath.appendingPathComponent("app_volumes.json") }

    func load() -> [String: Float] {
        try? FileManager.default.createDirectory(at: storagePath, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: volumesFile.path),
              let data = try? Data(contentsOf: volumesFile),
              let dict = try? JSONDecoder().decode([String: Float].self, from: data)
        else { return [:] }
        return dict
    }

    func save(_ volumes: [String: Float]) {
        try? FileManager.default.createDirectory(at: storagePath, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(volumes) else { return }
        try? data.write(to: volumesFile, options: .atomic)
    }
}

// MARK: - ViewModel

final class VolumeMonitor: NSObject, ObservableObject {
    @Published var outputVolume: Float = 0.5
    @Published var inputVolume: Float = 0.5
    @Published var isMuted: Bool = false
    @Published var isInputMuted: Bool = false
    @Published var outputDevices: [AudioDevice] = []
    @Published var inputDevices: [AudioDevice] = []
    @Published var currentOutputID: AudioDeviceID = 0
    @Published var currentInputID: AudioDeviceID = 0
    @Published var audioApps: [AudioApp] = []
    @Published var currentView: ViewMode = .controls
    @Published var selectedAppForMixer: AudioApp? = nil

    @AppStorage("showInput") var showInput: Bool = true
    @AppStorage("showApps") var showApps: Bool = true
    @AppStorage("appTheme") var appTheme: String = "system"

    private var pollTimer: Timer?
    private var appVolumes: [String: Float] = [:]

    override init() {
        super.init()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.startMonitoring()
        }
    }

    func startMonitoring() {
        appVolumes = AppVolumeStorage.shared.load()
        refreshAll()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
    }

    private func refreshAll() {
        let allDevices = AudioHelper.getAllDevices()
        outputDevices = allDevices.filter(\.isOutput)
        inputDevices = allDevices.filter(\.isInput)

        currentOutputID = AudioHelper.getDefaultDevice(isInput: false)
        currentInputID = AudioHelper.getDefaultDevice(isInput: true)

        outputVolume = AudioHelper.getVolume(device: currentOutputID, isInput: false)
        inputVolume = AudioHelper.getVolume(device: currentInputID, isInput: true)
        isMuted = AudioHelper.getMute(device: currentOutputID, isInput: false)
        isInputMuted = AudioHelper.getMute(device: currentInputID, isInput: true)

        if showApps {
            audioApps = AudioHelper.getAudioApps().map { app in
                var updated = app
                updated.volume = appVolumes[app.name] ?? 0.5
                return updated
            }
        }
    }

    func setOutputVolume(_ v: Float) {
        outputVolume = v
        AudioHelper.setVolume(device: currentOutputID, volume: v, isInput: false)
    }

    func setInputVolume(_ v: Float) {
        inputVolume = v
        AudioHelper.setVolume(device: currentInputID, volume: v, isInput: true)
    }

    func setAppVolume(_ app: AudioApp, volume: Float) {
        appVolumes[app.name] = volume
        AppVolumeStorage.shared.save(appVolumes)
        if let idx = audioApps.firstIndex(where: { $0.id == app.id }) {
            audioApps[idx].volume = volume
        }
    }

    func toggleMute() {
        isMuted.toggle()
        AudioHelper.setMute(device: currentOutputID, muted: isMuted, isInput: false)
    }

    func toggleInputMute() {
        isInputMuted.toggle()
        AudioHelper.setMute(device: currentInputID, muted: isInputMuted, isInput: true)
    }

    func setOutputDevice(_ id: AudioDeviceID) {
        AudioHelper.setDefaultDevice(id, isInput: false)
        currentOutputID = id
        outputVolume = AudioHelper.getVolume(device: id, isInput: false)
    }

    func setInputDevice(_ id: AudioDeviceID) {
        AudioHelper.setDefaultDevice(id, isInput: true)
        currentInputID = id
        inputVolume = AudioHelper.getVolume(device: id, isInput: true)
    }

    deinit { pollTimer?.invalidate() }
}

// MARK: - Volume Slider Row

struct VolumeRow: View {
    let label: String
    let icon: String
    let mutedIcon: String
    @Binding var volume: Float
    let isMuted: Bool
    let onVolumeChange: (Float) -> Void
    let onToggleMute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button(action: onToggleMute) {
                    Image(systemName: isMuted ? mutedIcon : icon)
                        .frame(width: 20)
                        .foregroundStyle(isMuted ? .red : .primary)
                }
                .buttonStyle(.plain)

                Slider(value: $volume, in: 0...1) { editing in
                    if !editing { onVolumeChange(volume) }
                }
                .onChange(of: volume) { newVal in
                    onVolumeChange(newVal)
                }

                Text("\(Int(volume * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}

// MARK: - App Mixer View

struct AppMixerView: View {
    @ObservedObject var monitor: VolumeMonitor

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { withAnimation { monitor.currentView = .controls } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.callout)
                        Text("Back").font(.callout)
                    }.foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("App Volume Mixer").font(.headline)
                Spacer()
                Text("Back").font(.callout).opacity(0)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if monitor.audioApps.isEmpty {
                        Text("No audio apps running")
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(monitor.audioApps) { app in
                            HStack(spacing: 12) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .cornerRadius(4)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(app.name)
                                        .font(.callout)
                                        .lineLimit(1)
                                    HStack(spacing: 8) {
                                        Slider(value: .init(
                                            get: { app.volume },
                                            set: { monitor.setAppVolume(app, volume: $0) }
                                        ), in: 0...1)

                                        Text("\(Int(app.volume * 100))%")
                                            .font(.system(size: 10, design: .monospaced))
                                            .frame(width: 32, alignment: .trailing)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
            }

            Divider()

            HStack {
                Text("Individual app volume levels")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
        }
        .frame(width: 380, height: 460)
    }
}

// MARK: - Controls View

struct VolumeControlView: View {
    @ObservedObject var monitor: VolumeMonitor

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("VolPerApp")
                    .font(.headline)
                Spacer()
                if !monitor.audioApps.isEmpty {
                    Button { withAnimation { monitor.currentView = .appMixer } } label: {
                        Image(systemName: "slider.horizontal.3").foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("App mixer")
                }
                Button { withAnimation { monitor.currentView = .settings } } label: {
                    Image(systemName: "gearshape").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VolumeRow(
                        label: "OUTPUT",
                        icon: volumeIcon(monitor.outputVolume),
                        mutedIcon: "speaker.slash.fill",
                        volume: $monitor.outputVolume,
                        isMuted: monitor.isMuted,
                        onVolumeChange: { monitor.setOutputVolume($0) },
                        onToggleMute: { monitor.toggleMute() }
                    )

                    if monitor.outputDevices.count > 1 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("OUTPUT DEVICE")
                                .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                            ForEach(monitor.outputDevices) { device in
                                Button {
                                    monitor.setOutputDevice(device.id)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: device.id == monitor.currentOutputID ? "checkmark.circle.fill" : "circle")
                                            .font(.caption)
                                            .foregroundStyle(device.id == monitor.currentOutputID ? .green : .secondary)
                                        Text(device.name)
                                            .font(.callout)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if monitor.showInput {
                        Divider()
                        VolumeRow(
                            label: "INPUT",
                            icon: "mic.fill",
                            mutedIcon: "mic.slash.fill",
                            volume: $monitor.inputVolume,
                            isMuted: monitor.isInputMuted,
                            onVolumeChange: { monitor.setInputVolume($0) },
                            onToggleMute: { monitor.toggleInputMute() }
                        )

                        if monitor.inputDevices.count > 1 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("INPUT DEVICE")
                                    .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                                ForEach(monitor.inputDevices) { device in
                                    Button {
                                        monitor.setInputDevice(device.id)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: device.id == monitor.currentInputID ? "checkmark.circle.fill" : "circle")
                                                .font(.caption)
                                                .foregroundStyle(device.id == monitor.currentInputID ? .green : .secondary)
                                            Text(device.name)
                                                .font(.callout)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 3)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if monitor.showApps && !monitor.audioApps.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("RUNNING APPS (\(monitor.audioApps.count))")
                                .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                            ForEach(monitor.audioApps.prefix(5)) { app in
                                HStack(spacing: 8) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                    }
                                    Text(app.name)
                                        .font(.callout)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(Int(app.volume * 100))%")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            if monitor.audioApps.count > 5 {
                                Text("+ \(monitor.audioApps.count - 5) more")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .padding(14)
            }

            Divider()

            HStack {
                Text("\(monitor.outputDevices.count) output, \(monitor.inputDevices.count) input")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
        }
        .frame(width: 380, height: 460)
    }

    private func volumeIcon(_ v: Float) -> String {
        if v == 0 { return "speaker.fill" }
        if v < 0.33 { return "speaker.wave.1.fill" }
        if v < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var monitor: VolumeMonitor

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { withAnimation { monitor.currentView = .controls } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.callout)
                        Text("Back").font(.callout)
                    }.foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Settings").font(.headline)
                Spacer()
                Text("Back").font(.callout).opacity(0)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section("DISPLAY") {
                        Toggle("Show input volume", isOn: $monitor.showInput).font(.callout)
                        Toggle("Show running apps", isOn: $monitor.showApps).font(.callout)
                    }

                    section("APPEARANCE") {
                        Picker("Theme", selection: $monitor.appTheme) {
                            ForEach(AppTheme.allCases, id: \.rawValue) {
                                Text($0.rawValue.capitalized).tag($0.rawValue)
                            }
                        }
                        .pickerStyle(.segmented).labelsHidden()
                    }

                    section("ABOUT") {
                        Text("VolPerApp v2.0").font(.callout)
                        Text("System volume + per-app mixer with device switching.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }

            Divider()

            HStack {
                Spacer()
                Button("Quit VolPerApp") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain).font(.callout).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .frame(width: 380, height: 460)
    }

    @ViewBuilder
    private func section<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
            content()
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @ObservedObject var monitor: VolumeMonitor

    var body: some View {
        Group {
            switch monitor.currentView {
            case .controls: VolumeControlView(monitor: monitor)
            case .appMixer: AppMixerView(monitor: monitor)
            case .settings: SettingsView(monitor: monitor)
            }
        }
        .onAppear { applyTheme() }
        .onChange(of: monitor.appTheme) { _ in applyTheme() }
    }

    private func applyTheme() {
        switch monitor.appTheme {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":  NSApp.appearance = NSAppearance(named: .darkAqua)
        default:      NSApp.appearance = nil
        }
    }
}

// MARK: - App Entry

@main
struct VolPerAppApp: App {
    @StateObject private var monitor = VolumeMonitor()

    var body: some Scene {
        MenuBarExtra {
            ContentView(monitor: monitor)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: monitor.isMuted ? "speaker.slash.fill" : volumeIcon)
                Text("\(Int(monitor.outputVolume * 100))%")
            }
            .font(.system(.body))
        }
        .menuBarExtraStyle(.window)
    }

    private var volumeIcon: String {
        if monitor.outputVolume == 0 { return "speaker.fill" }
        if monitor.outputVolume < 0.33 { return "speaker.wave.1.fill" }
        if monitor.outputVolume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
