import Foundation

/// Thin wrappers around the `gh` and `git` CLIs. Everything account-scoped
/// is done by injecting `GH_TOKEN` for the target account rather than
/// running `gh auth switch`, so RepoShelf never disturbs the active
/// account in the user's own terminal.
enum GitHub {

    // MARK: Accounts

    /// Parses `gh auth status` for github.com accounts.
    static func accounts() async throws -> [Account] {
        guard Shell.locate("gh") != nil else { throw ShellError.toolNotFound("gh") }
        let result = try await Shell.require("gh", ["auth", "status"])
        var accounts: [Account] = []
        var pending: String?
        for rawLine in result.stdout.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if let name = firstMatch(in: line, pattern: #"Logged in to [^ ]+ account ([^ ]+)"#) {
                pending = name
                accounts.append(Account(login: name, isActive: false))
            } else if line.contains("Active account: true"), let name = pending,
                      let idx = accounts.firstIndex(where: { $0.login == name }) {
                accounts[idx].isActive = true
            }
        }
        return accounts
    }

    /// The API token for a specific account, without switching the active one.
    static func token(for login: String) async throws -> String {
        let result = try await Shell.require("gh", ["auth", "token", "--user", login])
        let token = result.trimmedOut
        guard !token.isEmpty else {
            throw ShellError.failed(command: "gh auth token", status: 1, message: "empty token for \(login)")
        }
        return token
    }

    private static func env(token: String) -> [String: String] {
        ["GH_TOKEN": token, "GH_HOST": "github.com", "GH_PROMPT_DISABLED": "1", "CLICOLOR": "0"]
    }

    // MARK: Repo listing

    private struct GHRepoJSON: Decodable {
        var name: String
        var nameWithOwner: String
        var description: String?
        var isPrivate: Bool
        var pushedAt: String?
        var url: String
        var diskUsage: Int?
    }

    /// Repos owned by `login` (and repos it collaborates on), newest push first.
    static func repos(for login: String, token: String) async throws -> [RemoteRepo] {
        let fields = "name,nameWithOwner,description,isPrivate,pushedAt,url,diskUsage"
        let result = try await Shell.require(
            "gh",
            ["repo", "list", login, "--no-archived", "--limit", "500", "--json", fields],
            env: env(token: token)
        )
        let data = Data(result.stdout.utf8)
        let decoded = try JSONDecoder().decode([GHRepoJSON].self, from: data)
        let iso = ISO8601DateFormatter()
        return decoded.map { r in
            RemoteRepo(
                name: r.name,
                nameWithOwner: r.nameWithOwner,
                description: r.description ?? "",
                isPrivate: r.isPrivate,
                pushedAt: r.pushedAt.flatMap { iso.date(from: $0) },
                url: r.url,
                diskUsageKB: r.diskUsage ?? 0
            )
        }
        .sorted { ($0.pushedAt ?? .distantPast) > ($1.pushedAt ?? .distantPast) }
    }

    /// Metadata for a single repo referenced as `owner/name` — used when the
    /// user pastes a URL for a repo outside their own list.
    static func repoView(slug: String, token: String) async throws -> RemoteRepo {
        let fields = "name,nameWithOwner,description,isPrivate,pushedAt,url,diskUsage"
        let result = try await Shell.require(
            "gh", ["repo", "view", slug, "--json", fields], env: env(token: token)
        )
        let r = try JSONDecoder().decode(GHRepoJSON.self, from: Data(result.stdout.utf8))
        let iso = ISO8601DateFormatter()
        return RemoteRepo(
            name: r.name,
            nameWithOwner: r.nameWithOwner,
            description: r.description ?? "",
            isPrivate: r.isPrivate,
            pushedAt: r.pushedAt.flatMap { iso.date(from: $0) },
            url: r.url,
            diskUsageKB: r.diskUsage ?? 0,
            isManuallyAdded: true
        )
    }

    // MARK: Clone / remove

    /// Clones `repo` into `destination` with the chosen strategy, then writes
    /// the account's commit identity into the clone's local config.
    static func clone(
        slug: String,
        into destination: URL,
        strategy: CloneStrategy,
        token: String,
        identity: GitIdentity?
    ) async throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var args = ["repo", "clone", slug, destination.path]
        if !strategy.gitArgs.isEmpty {
            args.append("--")
            args.append(contentsOf: strategy.gitArgs)
        }
        try await Shell.require("gh", args, env: env(token: token))

        if let identity, !identity.isBlank {
            if !identity.name.isEmpty {
                _ = try? await Shell.require("git", ["-C", destination.path, "config", "user.name", identity.name])
            }
            if !identity.email.isEmpty {
                _ = try? await Shell.require("git", ["-C", destination.path, "config", "user.email", identity.email])
            }
        }
    }

    // MARK: Publish a local folder

    static func isGitRepo(_ dir: URL) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(".git").path)
    }

    /// Turns a local folder into a new GitHub repo: `git init` + commit if
    /// needed, then `gh repo create --source --push`.
    static func publish(
        folder: URL,
        owner: String,
        name: String,
        description: String,
        isPrivate: Bool,
        token: String,
        identity: GitIdentity?
    ) async throws {
        let path = folder.path

        if !isGitRepo(folder) {
            try await Shell.require("git", ["-C", path, "init"])
        }

        if let identity, !identity.isBlank {
            if !identity.name.isEmpty {
                _ = try? await Shell.require("git", ["-C", path, "config", "user.name", identity.name])
            }
            if !identity.email.isEmpty {
                _ = try? await Shell.require("git", ["-C", path, "config", "user.email", identity.email])
            }
        }

        let gitPath = Shell.locate("git")
        let hasHead = gitPath.flatMap { Shell.runSyncCapture($0, ["-C", path, "rev-parse", "--verify", "HEAD"]) } != nil
        let dirty = gitPath.flatMap { Shell.runSyncCapture($0, ["-C", path, "status", "--porcelain"]) }?.isEmpty == false

        if !hasHead || dirty {
            _ = try await Shell.require("git", ["-C", path, "add", "-A"])
            let staged = gitPath.flatMap { Shell.runSyncCapture($0, ["-C", path, "diff", "--cached", "--name-only"]) }
            guard !(staged?.isEmpty ?? true) || hasHead else {
                throw ShellError.failed(command: "git commit", status: 1, message: "the folder has no files to commit")
            }
            if !(staged?.isEmpty ?? true) {
                try await Shell.require("git", ["-C", path, "commit", "-m", hasHead ? "Add files" : "Initial commit"])
            }
        }

        var args = ["repo", "create", "\(owner)/\(name)", "--source", path, "--remote", "origin", "--push"]
        args.append(isPrivate ? "--private" : "--public")
        if !description.trimmingCharacters(in: .whitespaces).isEmpty {
            args.append(contentsOf: ["--description", description])
        }
        try await Shell.require("gh", args, env: env(token: token))
    }

    // MARK: Local scan

    private static let scanSkipDirs: Set<String> = [
        "node_modules", "Library", ".Trash", "Pods", "Carthage", "vendor",
        ".build", "DerivedData", "dist", "build", ".next", "target",
        ".gradle", ".venv", "venv", "__pycache__", "Applications",
    ]

    private static let homeSkipDirs: Set<String> = [
        "Library", "Applications", "Desktop", "Documents", "Downloads",
        "Movies", "Music", "Pictures", "Public", "Sites",
        "Parallels", "Creative Cloud Files", "Pictures Library.photoslibrary",
    ]

    struct ScanResult {
        var clones: [LocalRepo]
        /// Top-level folders inside the scan roots that are NOT git checkouts
        /// — used to flag "you have a folder for this repo but never cloned it".
        var looseDirs: [URL]
    }

    /// Recursively finds git working copies under any of `roots` (bounded
    /// depth), keyed by the `owner/repo` parsed from each clone's `origin`
    /// remote — so a repo maps to its GitHub identity regardless of where it
    /// sits on disk or what the folder is called. Clones without a GitHub
    /// origin are kept under `local/<folder>`.
    static func scan(roots: [URL], maxDepth: Int = 4) -> ScanResult {
        let fm = FileManager.default
        let gitPath = Shell.locate("git")
        var byPath: [String: LocalRepo] = [:]
        var loose: [URL] = []

        func isRepo(_ dir: URL) -> Bool {
            fm.fileExists(atPath: dir.appendingPathComponent(".git").path)
        }

        func record(_ dir: URL) {
            let origin = originSlug(at: dir, gitPath: gitPath)
            byPath[dir.path] = LocalRepo(
                nameWithOwner: origin.slug ?? "local/\(dir.lastPathComponent)",
                path: dir,
                sizeBytes: directorySize(dir),
                originSlug: origin.slug,
                originURL: origin.url
            )
        }

        func walk(_ dir: URL, depth: Int, collectLoose: Bool) {
            if isRepo(dir) { record(dir); return } // don't descend into a repo
            guard depth < maxDepth,
                  let children = try? fm.contentsOfDirectory(
                      at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                      options: [.skipsHiddenFiles, .skipsPackageDescendants]
                  )
            else { return }
            for child in children {
                guard (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                      !scanSkipDirs.contains(child.lastPathComponent)
                else { continue }
                if collectLoose, !isRepo(child) { loose.append(child) }
                walk(child, depth: depth + 1, collectLoose: false)
            }
        }

        var seenRoots = Set<String>()
        for root in roots {
            let standardized = root.standardizedFileURL
            guard fm.fileExists(atPath: standardized.path), seenRoots.insert(standardized.path).inserted else { continue }
            walk(standardized, depth: 0, collectLoose: true)
        }

        // Also pick up repos sitting directly in the home folder (shallow —
        // don't recurse the whole home directory).
        let home = fm.homeDirectoryForCurrentUser.standardizedFileURL
        if seenRoots.insert(home.path).inserted,
           let children = try? fm.contentsOfDirectory(
               at: home, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
           ) {
            for child in children {
                guard (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                      !homeSkipDirs.contains(child.lastPathComponent),
                      !scanSkipDirs.contains(child.lastPathComponent),
                      isRepo(child)
                else { continue }
                record(child)
            }
        }

        // Collapse duplicate checkouts of the same repo, keeping the biggest.
        var byKey: [String: LocalRepo] = [:]
        for repo in byPath.values {
            if let existing = byKey[repo.nameWithOwner], existing.sizeBytes >= repo.sizeBytes { continue }
            byKey[repo.nameWithOwner] = repo
        }
        return ScanResult(clones: Array(byKey.values), looseDirs: loose)
    }

    private static func originSlug(at dir: URL, gitPath: String?) -> (slug: String?, url: String?) {
        guard let gitPath,
              let url = Shell.runSyncCapture(gitPath, ["-C", dir.path, "config", "--get", "remote.origin.url"]),
              !url.isEmpty
        else { return (nil, nil) }
        return (parseSlug(url), url)
    }

    static func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: []
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }

    // MARK: Helpers

    /// A `slug` from a pasted URL or `owner/name` string, or nil if unparseable.
    static func parseSlug(_ input: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "git@github.com:", with: "")
        if let range = s.range(of: "://") { s = String(s[range.upperBound...]) }
        if s.hasPrefix("github.com/") { s = String(s.dropFirst("github.com/".count)) }
        if s.hasSuffix(".git") { s = String(s.dropLast(4)) }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = s.split(separator: "/")
        guard parts.count == 2,
              parts.allSatisfy({ $0.range(of: #"^[\w.-]+$"#, options: .regularExpression) != nil })
        else { return nil }
        return "\(parts[0])/\(parts[1])"
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
