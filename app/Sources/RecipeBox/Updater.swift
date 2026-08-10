import Foundation
import AppKit

// Lightweight auto-updater backed by the public repo's GitHub Releases.
// Checks the latest release, and if newer, downloads the zipped .app and swaps it
// in via a detached helper (waits for quit → replace → de-quarantine → re-sign →
// relaunch). No server, no embedded token (public repo assets download over HTTPS).
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    static let owner = "infinitemeadow"
    static let repo = "recipe-box"

    enum State: Equatable {
        case idle
        case checking
        case available(version: String, url: URL)
        case downloading
    }

    @Published var state: State = .idle
    @Published var transientMessage: String?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func check(userInitiated: Bool = false) {
        Task {
            if case .downloading = state { return }
            state = .checking
            do {
                let (tag, assetURL) = try await fetchLatest()
                if versionCompare(strip(tag), currentVersion) > 0 {
                    state = .available(version: strip(tag), url: assetURL)
                } else {
                    state = .idle
                    if userInitiated { flash("You're on the latest version (\(currentVersion)).") }
                }
            } catch {
                state = .idle
                if userInitiated { flash("Update check failed: \(error.localizedDescription)") }
            }
        }
    }

    func installUpdate(from url: URL) {
        Task {
            state = .downloading
            do {
                let (tmpFile, _) = try await URLSession.shared.download(from: url)
                let work = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("RecipeBoxUpdate-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                let zip = work.appendingPathComponent("update.zip")
                try FileManager.default.moveItem(at: tmpFile, to: zip)
                try run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])
                let newApp = work.appendingPathComponent("RecipeBox.app")
                guard FileManager.default.fileExists(atPath: newApp.path) else {
                    throw err("The downloaded update was malformed.")
                }
                try swapAndRelaunch(newApp: newApp)
            } catch {
                state = .idle
                flash("Update failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - internals

    private func fetchLatest() async throws -> (String, URL) {
        let api = "https://api.github.com/repos/\(Self.owner)/\(Self.repo)/releases/latest"
        var req = URLRequest(url: URL(string: api)!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("RecipeBox", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw err("No published releases yet.")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let tag = json?["tag_name"] as? String,
              let assets = json?["assets"] as? [[String: Any]],
              let zip = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
              let urlStr = zip["browser_download_url"] as? String,
              let url = URL(string: urlStr) else {
            throw err("That release has no downloadable app.")
        }
        return (tag, url)
    }

    private func swapAndRelaunch(newApp: URL) throws {
        let target = Bundle.main.bundlePath
        let helper = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rb-update-\(UUID().uuidString).sh")
        let script = """
        #!/bin/bash
        TARGET="$1"
        NEW="$2"
        for _ in $(seq 1 120); do
          pgrep -x RecipeBox >/dev/null || break
          sleep 0.5
        done
        rm -rf "$TARGET"
        cp -R "$NEW" "$TARGET"
        xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
        codesign --force --sign - "$TARGET" >/dev/null 2>&1 || true
        open "$TARGET"
        """
        try script.write(to: helper, atomically: true, encoding: .utf8)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [helper.path, target, newApp.path]
        try p.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
    }

    private func run(_ launch: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw err("\(launch) failed") }
    }

    private func flash(_ message: String) {
        transientMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if transientMessage == message { transientMessage = nil }
        }
    }

    private func strip(_ v: String) -> String { v.hasPrefix("v") ? String(v.dropFirst()) : v }

    private func versionCompare(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x - y }
        }
        return 0
    }

    private func err(_ msg: String) -> NSError {
        NSError(domain: "Updater", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
