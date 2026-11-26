import AppKit
import Foundation

/// Keeps exactly one Swip running per user session.
///
/// Two copies can end up launched together — typically the installed app in
/// /Applications and a development build in `dist/`, both registered as login
/// items. Every instance applies the same deterministic ranking, so they always
/// agree on the survivor without needing to talk to each other:
///   1. an installed copy beats a development build;
///   2. otherwise the older process (lower PID) wins.
@MainActor
enum InstanceGuard {
    /// True when this bundle lives in an Applications folder (i.e. a real install,
    /// not a build product inside a source checkout).
    nonisolated static var isInstalledCopy: Bool { isInstalled(Bundle.main.bundleURL) }

    nonisolated static func isInstalled(_ url: URL?) -> Bool {
        guard let path = url?.resolvingSymlinksInPath().path else { return false }
        let userApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications").path
        return path.hasPrefix("/Applications/") || path.hasPrefix(userApps + "/")
    }

    /// Returns `false` when another running instance outranks this one and this
    /// process should quit. Outranked peers are asked to terminate.
    static func resolve() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return true }
        let me = NSRunningApplication.current
        let peers = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != me.processIdentifier && !$0.isTerminated }
        guard !peers.isEmpty else { return true }

        if let winner = peers.first(where: { outranks($0, me) }) {
            DiagnosticLog.log("InstanceGuard: yielding to pid \(winner.processIdentifier) at \(winner.bundleURL?.path ?? "?")")
            return false
        }
        for peer in peers {
            DiagnosticLog.log("InstanceGuard: terminating duplicate pid \(peer.processIdentifier) at \(peer.bundleURL?.path ?? "?")")
            peer.terminate()
        }
        return true
    }

    private static func outranks(_ a: NSRunningApplication, _ b: NSRunningApplication) -> Bool {
        let aInstalled = isInstalled(a.bundleURL)
        let bInstalled = isInstalled(b.bundleURL)
        if aInstalled != bInstalled { return aInstalled }
        return a.processIdentifier < b.processIdentifier
    }
}
