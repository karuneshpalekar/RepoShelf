import Foundation

/// The git commit identity written into a clone's `.git/config` so commits
/// from this account are attributed correctly regardless of the global
/// `~/.gitconfig`.
struct GitIdentity: Codable, Equatable {
    var name: String
    var email: String

    var isBlank: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

enum CloneStrategy: String, Codable, CaseIterable, Identifiable {
    case blobless
    case shallow
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blobless: return "Blobless"
        case .shallow: return "Shallow"
        case .full: return "Full"
        }
    }

    var subtitle: String {
        switch self {
        case .blobless: return "Full history, file contents fetched on demand. Best default."
        case .shallow: return "Latest commit only. Smallest, but no history or blame."
        case .full: return "Everything, offline forever. Largest."
        }
    }

    /// Extra flags passed to `git clone` (after `gh repo clone <slug> <dir> --`).
    var gitArgs: [String] {
        switch self {
        case .blobless: return ["--filter=blob:none"]
        case .shallow: return ["--depth=1"]
        case .full: return []
        }
    }

    /// Rough on-disk fraction of the repo's reported remote size.
    var sizeFactor: Double {
        switch self {
        case .blobless: return 0.35
        case .shallow: return 0.12
        case .full: return 1.0
        }
    }
}

struct ActivityEvent: Codable, Identifiable {
    enum Kind: String, Codable {
        case clone, remove, switchAccount, addAccount, publish
    }

    var id: UUID = UUID()
    var date: Date = Date()
    var kind: Kind
    var subject: String
    var detail: String
}

/// Persisted app state (JSON at ~/Library/Application Support/RepoShelf/state.json).
struct RepoShelfState: Codable {
    var workspaceRootPath: String = SharedStorage.defaultWorkspaceRoot.path
    /// Folders scanned for existing clones. Empty means "resolve defaults";
    /// first launch fills it with the default candidates that exist.
    var scanRootPaths: [String] = []
    /// login -> commit identity
    var identities: [String: GitIdentity] = [:]
    /// repo nameWithOwner -> strategy it was cloned with
    var cloneStrategies: [String: CloneStrategy] = [:]
    /// repo nameWithOwner -> last time opened in the editor (or clone time)
    var lastOpened: [String: Date] = [:]
    /// manually added repos (nameWithOwner) that aren't in `gh repo list`
    var addedRepos: [AddedRepo] = []
    /// Every repo RepoShelf has seen on disk or cloned — kept so a repo stays
    /// in the Repos list (with a Download button) after it's cleaned up.
    var knownRepos: [KnownRepo] = []
    var activity: [ActivityEvent] = []
    var appearanceRaw: String = "system"

    struct AddedRepo: Codable, Identifiable {
        var id: String { nameWithOwner }
        var nameWithOwner: String
        var cloneURL: String
        var login: String
    }

    struct KnownRepo: Codable, Identifiable {
        var id: String { nameWithOwner }
        var nameWithOwner: String
        var cloneURL: String
        /// The owner/org — used to display it and to pick which account's
        /// token can fetch it.
        var login: String
        /// `~`-relative parent folder the clone last lived in, so a
        /// re-download lands back where it was.
        var lastParentPath: String?
    }

    var workspaceRoot: URL {
        URL(fileURLWithPath: (workspaceRootPath as NSString).expandingTildeInPath)
    }
}

/// A repo as reported by `gh repo list`.
struct RemoteRepo: Identifiable, Equatable {
    var id: String { nameWithOwner }
    var name: String
    var nameWithOwner: String
    var description: String
    var isPrivate: Bool
    var pushedAt: Date?
    var url: String
    /// Remote repo size in kilobytes, as reported by GitHub.
    var diskUsageKB: Int
    /// True when the user added this manually rather than it coming from the list.
    var isManuallyAdded: Bool = false
    /// True when this row exists only because a clone was found on disk that
    /// isn't in the active account's `gh repo list`.
    var isDetectedLocal: Bool = false
}

/// A clone found on disk in one of the scanned folders.
struct LocalRepo {
    /// `owner/repo` parsed from the clone's `origin` remote, or
    /// `local/<folder>` when there's no GitHub origin.
    var nameWithOwner: String
    var path: URL
    var sizeBytes: Int64
    var originSlug: String?
    var originURL: String?

    var isLocalOnly: Bool { originSlug == nil }
}

/// A GitHub account known to `gh`.
struct Account: Identifiable, Equatable {
    var id: String { login }
    var login: String
    var isActive: Bool
}

enum Formatting {
    static func size(bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useMB, .useGB, .useKB]
        return f.string(fromByteCount: bytes)
    }

    static func size(kb: Int) -> String {
        size(bytes: Int64(kb) * 1024)
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "unknown" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
