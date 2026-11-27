import Security
import SwiftUI

struct Screen: Decodable {
    let image_url: URL
}

enum Keychain {
    private static let item: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.jkrenge.trmnl-menubar",
        kSecAttrAccount as String: "device-api-key",
    ]

    static func get() -> String? {
        var query = item
        query[kSecReturnData as String] = true
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String) {
        SecItemDelete(item as CFDictionary)
        guard !value.isEmpty else { return }
        var query = item
        query[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(query as CFDictionary, nil)
    }
}

@MainActor
final class Model: ObservableObject {
    @Published var image: NSImage?
    @Published var error: String?
    @Published var key = Keychain.get()
    private var loop: Task<Void, Never>?

    init() { start() }

    func setKey(_ value: String) {
        Keychain.set(value.trimmingCharacters(in: .whitespacesAndNewlines))
        key = Keychain.get()
        image = nil
        error = nil
        start()
    }

    private func start() {
        loop?.cancel()
        loop = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    func refresh() async {
        guard let key else { return }
        do {
            // current_screen, not display: it does not advance the playlist.
            var request = URLRequest(url: URL(string: "https://trmnl.com/api/current_screen")!)
            request.setValue(key, forHTTPHeaderField: "access-token")
            let (json, _) = try await URLSession.shared.data(for: request)
            guard let screen = try? JSONDecoder().decode(Screen.self, from: json) else {
                error = "TRMNL returned no screen. Check the API key."
                return
            }
            let (bytes, _) = try await URLSession.shared.data(from: screen.image_url)
            guard let loaded = NSImage(data: bytes) else { throw URLError(.cannotDecodeContentData) }
            image = loaded
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// Pick one that matches what your playlist shows: screen, weather, to-dos, tracking, stocks, calendar, misc.
let menuBarIcons = [
    "photo.artframe", "display", "cloud.sun", "thermometer.medium",
    "checklist", "checkmark.circle", "chart.line.uptrend.xyaxis", "chart.bar",
    "gauge.with.dots.needle.33percent", "dollarsign.circle", "calendar", "clock",
    "newspaper", "house", "figure.run", "quote.bubble",
]

func isSymbol(_ name: String) -> Bool {
    NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
}

struct ContentView: View {
    @ObservedObject var model: Model
    @State private var showSettings = false
    @State private var draft = ""
    @State private var iconName = ""
    // 100% = one point per two image pixels: pixel-exact on Retina, as are 50% and 200%.
    @AppStorage("imageScale") private var scale = 1.0
    @AppStorage("menuBarIcon") private var icon = "photo.artframe"

    private var imageSize: CGSize {
        let rep = model.image?.representations.first
        return CGSize(width: CGFloat(rep?.pixelsWide ?? 800) / 2 * scale,
                      height: CGFloat(rep?.pixelsHigh ?? 480) / 2 * scale)
    }

    var body: some View {
        Group {
            if model.key == nil || showSettings { settings } else { screen }
        }
        .padding(10)
        .fixedSize()  // the popover takes exactly the content's size
    }

    // Fixed width, no image: changing the scale here never resizes the open popover.
    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if model.key != nil {
                    Button("Back", systemImage: "chevron.left") { showSettings = false }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
                Text("Settings").font(.headline)
                Spacer()
                Button("Quit", systemImage: "power") { NSApp.terminate(nil) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Image scale").font(.subheadline)
                HStack(spacing: 4) {
                    ForEach([0.5, 0.75, 1.0, 1.5, 2.0], id: \.self) { value in
                        let label = "\(Int(value * 100))%"
                        option(label, selected: scale == value) { scale = value } content: { Text(label) }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Menu bar icon").font(.subheadline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                    ForEach(menuBarIcons, id: \.self) { name in
                        option(name, selected: icon == name) { icon = name } content: { Image(systemName: name) }
                    }
                }
                TextField("Any SF Symbol name", text: $iconName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: iconName) { if isSymbol(iconName) { icon = iconName } }
                if isSymbol(iconName) {
                    Text("Browse all names in the [SF Symbols app](https://developer.apple.com/sf-symbols/).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("No SF Symbol is called “\(iconName)”. Keeping \(icon).", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Device API key").font(.subheadline)
                SecureField(model.key == nil ? "Paste your API key" : "Saved. Paste a new one to replace it", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        guard !draft.isEmpty else { return }  // a stray Return must not wipe the saved key
                        model.setKey(draft)
                        draft = ""
                        showSettings = false
                    }
                Text("In TRMNL: [Devices](https://trmnl.com/devices) → your device → API Key. Press Return to save. Stored in your macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 340)
        .onAppear { iconName = icon }
        .onChange(of: icon) { iconName = icon }  // a grid pick shows up in the text field
    }

    // One selectable tile, shared by the scale row and the icon grid so both look and read alike.
    private func option<Content: View>(_ label: String, selected: Bool, action: @escaping () -> Void,
                                       @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(selected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var screen: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = model.image {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Current TRMNL screen")
            } else if model.error == nil {
                ProgressView().frame(width: imageSize.width, height: imageSize.height)
            }
            HStack {
                Group {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .labelStyle(.titleAndIcon).font(.caption).lineLimit(2)
                    }
                    Spacer()
                    Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                    Button("Quit", systemImage: "power") { NSApp.terminate(nil) }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
        .frame(width: max(imageSize.width, 200))  // room for the buttons at 50%
    }
}

// A plain status item + NSPopover: unlike MenuBarExtra, the popover opens centered under the icon
// and stays anchored there when its size changes.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = Model()
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingController(rootView: ContentView(model: model))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient  // closes on any click outside
        item.button?.target = self
        item.button?.action = #selector(toggle)
        updateIcon()
        NotificationCenter.default.addObserver(self, selector: #selector(updateIcon),
                                               name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc private func toggle() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            Task { await model.refresh() }
            NSApp.activate()  // lets the settings text fields take typing
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func updateIcon() {
        let name = UserDefaults.standard.string(forKey: "menuBarIcon") ?? "photo.artframe"
        // Fallback keeps the icon clickable if a saved symbol ever stops existing.
        item.button?.image = NSImage(systemSymbolName: isSymbol(name) ? name : "photo.artframe",
                                     accessibilityDescription: "Menu Bar Viewer for TRMNL")
    }
}

@main
struct TRMNLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        guard CommandLine.arguments.contains("--selftest") else { return }
        let ok = Data(#"{"status":200,"refresh_rate":1800,"image_url":"https://trmnl.com/x.png"}"#.utf8)
        let noScreen = Data(#"{"status":202}"#.utf8)
        precondition((try? JSONDecoder().decode(Screen.self, from: ok))?.image_url.host == "trmnl.com")
        precondition((try? JSONDecoder().decode(Screen.self, from: noScreen)) == nil)
        for name in menuBarIcons {
            precondition(isSymbol(name), "missing SF Symbol \(name)")
        }
        precondition(!isSymbol("cloud.su") && !isSymbol(""))
        print("selftest ok")
        exit(0)
    }

    var body: some Scene {
        Settings { EmptyView() }  // no windows: everything lives in AppDelegate's status item
    }
}
