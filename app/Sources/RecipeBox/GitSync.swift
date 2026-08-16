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
    // Distinguishes real merge conflicts from auth/network failures (which must NOT
    // be reported as conflicts).
    static func sync(_ dir: URL) -> String {
        guard isRepo(dir) else { return "" }

        // 1) Commit real local changes.
        git(["add", "-A"], in: dir)
        if !git(["diff", "--cached", "--quiet"], in: dir).ok {
            git(["-c", "user.name=Recipe Box",
                 "-c", "user.email=recipebox@users.noreply.github.com",
                 "commit", "-m", "Update recipes"], in: dir)
        }

        // 2) Fetch — auth/network problems surface here, separate from conflicts.
        let fetch = git(["fetch", "origin"], in: dir)
        if !fetch.ok { return connectionMessage(fetch.out) }

        // 3) Replay local commits on top of the remote.
        let branch = git(["rev-parse", "--abbrev-ref", "HEAD"], in: dir)
            .out.trimmingCharacters(in: .whitespacesAndNewlines)
        let rebase = git(["rebase", "origin/\(branch)"], in: dir)
        if !rebase.ok {
            let conflicted = git(["diff", "--name-only", "--diff-filter=U"], in: dir).out
                .split(separator: "\n").map { ($0 as NSString).lastPathComponent }
            git(["rebase", "--abort"], in: dir)   // never leave a half-finished rebase
            if !conflicted.isEmpty {
                return "Conflict on \(conflicted.joined(separator: ", ")) — edited on both Macs"
            }
            return "Couldn't merge remote changes — try Sync again"
        }

        // 4) Push.
        let push = git(["push"], in: dir)
        return push.ok ? "Synced" : connectionMessage(push.out)
    }

    private static func connectionMessage(_ output: String) -> String {
        let o = output.lowercased()
        if o.contains("could not read username") || o.contains("authentication failed")
            || o.contains("permission") || o.contains("denied")
            || o.contains("terminal prompts disabled") || o.contains("device not configured") {
            return "Sign-in needed — run: gh auth login"
        }
        if o.contains("could not resolve host") || o.contains("connection")
            || o.contains("network") || o.contains("timed out") || o.contains("unable to access") {
            return "Offline — will sync when reconnected"
        }
        return "Sync issue — will retry"
    }
}
