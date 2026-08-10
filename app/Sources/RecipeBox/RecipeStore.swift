import Foundation
import SwiftUI

@MainActor
final class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var directory: URL

    private var watcher: FolderWatcher?

    init() {
        let saved = UserDefaults.standard.string(forKey: "libraryPath")
        directory = saved.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Recipes", isDirectory: true)
        ensureDirectory()
        reload()
        startWatching()
    }

    func setDirectory(_ url: URL) {
        directory = url
        UserDefaults.standard.set(url.path, forKey: "libraryPath")
        ensureDirectory()
        reload()
        startWatching()
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
