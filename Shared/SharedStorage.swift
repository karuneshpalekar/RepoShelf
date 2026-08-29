import Foundation

enum SharedStorage {
    static var directory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("RepoShelf", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static var stateURL: URL {
        directory.appendingPathComponent("state.json")
    }

    /// Default workspace root — clones land in ~/Code/<account>/<repo>.
    static var defaultWorkspaceRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Code", isDirectory: true)
    }

    /// Folders checked for existing clones on first launch (the ones that
    /// exist are kept). The user can add or remove folders afterward.
    static var defaultScanRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            "Code", "Downloads", "Documents/GitHub", "Documents/github",
            "Developer", "Projects", "src", "repos", "work",
        ].map { home.appendingPathComponent($0) }
    }
}
