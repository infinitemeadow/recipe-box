import Foundation

// Two-way recipe sync when the library folder is a git clone of the shared private
// repo. Commits local changes, rebases on remote, pushes. Auth rides on the user's
// existing git credentials (set up by `gh auth login`) — no token in the app.
enum GitSync {
    static func isRepo(_ dir: URL) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(".git").path)
    }

    @discardableResult
    static func git(_ args: [String], in dir: URL) -> (ok: Bool, out: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", dir.path] + args
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"   // never hang on a credential prompt
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (false, "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus == 0, String(data: data, encoding: .utf8) ?? "")
    }

    // Commit local edits → rebase on remote → push. Returns a short status string.
    static func sync(_ dir: URL) -> String {
        guard isRepo(dir) else { return "" }

        git(["add", "-A"], in: dir)
        let hasLocalChanges = !git(["diff", "--cached", "--quiet"], in: dir).ok
        if hasLocalChanges {
            git(["-c", "user.name=Recipe Box",
                 "-c", "user.email=recipebox@users.noreply.github.com",
                 "commit", "-m", "Update recipes"], in: dir)
        }

        let pull = git(["pull", "--rebase"], in: dir)
        if !pull.ok {
            git(["rebase", "--abort"], in: dir)   // never leave a half-finished rebase
            return "Sync conflict — same recipe edited on both Macs"
        }

        let push = git(["push"], in: dir)
        return push.ok ? "Synced" : "Sync issue — check your connection / sign-in"
    }
}
