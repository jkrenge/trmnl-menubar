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

struct ContentView: View {
    @ObservedObject var model: Model
    @State private var editingKey = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.key == nil || editingKey {
                SecureField("Device API key", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        model.setKey(draft)
                        draft = ""
                        editingKey = false
                    }
                Text("In TRMNL: Devices → your device → API Key. Press Return to save. Stored in your macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let image = model.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Current TRMNL screen")
            } else if model.error == nil {
                ProgressView().frame(maxWidth: .infinity, minHeight: 240)
            }
            HStack {
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle").font(.caption).lineLimit(2)
                }
                Spacer()
                Group {
                    Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                    Button("Change API key", systemImage: "lock.circle") { editingKey.toggle() }
                    Button("Quit", systemImage: "power") { NSApp.terminate(nil) }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .frame(width: 420)
        .onAppear { Task { await model.refresh() } }
    }
}

@main
struct TRMNLApp: App {
    @StateObject private var model = Model()

    init() {
        guard CommandLine.arguments.contains("--selftest") else { return }
        let ok = Data(#"{"status":200,"refresh_rate":1800,"image_url":"https://trmnl.com/x.png"}"#.utf8)
        let noScreen = Data(#"{"status":202}"#.utf8)
        precondition((try? JSONDecoder().decode(Screen.self, from: ok))?.image_url.host == "trmnl.com")
        precondition((try? JSONDecoder().decode(Screen.self, from: noScreen)) == nil)
        print("selftest ok")
        exit(0)
    }

    var body: some Scene {
        MenuBarExtra("TRMNL", systemImage: "photo.artframe") {
            ContentView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
