import Foundation
import SwiftUI

@MainActor
final class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var directory: URL
    @Published var syncStatus: String = ""
    @Published var isSyncing = false

    private var watcher: FolderWatcher?
    private var syncTimer: Timer?

    var canSync: Bool { GitSync.isRepo(directory) }

    init() {
        let saved = UserDefaults.standard.string(forKey: "libraryPath")
        directory = saved.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Recipes", isDirectory: true)
        ensureDirectory()
        reload()
        startWatching()
        syncNow()
        startSyncTimer()
    }

    func setDirectory(_ url: URL) {
        directory = url
        UserDefaults.standard.set(url.path, forKey: "libraryPath")
        ensureDirectory()
        reload()
        startWatching()
        syncNow()
        startSyncTimer()
    }

    // Commit/pull/push in the background, then refresh the list.
    func syncNow() {
        guard canSync, !isSyncing else { return }
        isSyncing = true
        let dir = directory
        Task {
            let status = await Task.detached { GitSync.sync(dir) }.value
            self.syncStatus = status
            self.isSyncing = false
            self.reload()
        }
    }

    private func startSyncTimer() {
        syncTimer?.invalidate()
        guard canSync else { return }
        syncTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.syncNow() }
        }
    }

    func reload() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey]
        let urls = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
        var loaded: [Recipe] = []
        for url in urls where url.pathExtension.lowercased() == "md" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let vals = try? url.resourceValues(forKeys: Set(keys))
            let date = vals?.creationDate ?? vals?.contentModificationDate
            loaded.append(MarkdownParser.parse(text, fileURL: url, fileDate: date))
        }
        loaded.sort { ($0.sortDate ?? .distantPast) > ($1.sortDate ?? .distantPast) }
        recipes = loaded
    }

    private func ensureDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func startWatching() {
        watcher = FolderWatcher(url: directory) { [weak self] in
            Task { @MainActor in self?.reload() }
        }
    }
}
