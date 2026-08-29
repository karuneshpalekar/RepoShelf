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

    // MARK: Local scan

    /// Finds clones two levels under `root` (root/<account>/<repo>/.git).
    static func scanClones(root: URL) -> [LocalRepo] {
        let fm = FileManager.default
        guard let accountDirs = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        var found: [LocalRepo] = []
        for accountDir in accountDirs {
            guard (try? accountDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                  let repoDirs = try? fm.contentsOfDirectory(
                      at: accountDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
                  )
            else { continue }

            for repoDir in repoDirs {
                let gitDir = repoDir.appendingPathComponent(".git")
                guard fm.fileExists(atPath: gitDir.path) else { continue }
                let nameWithOwner = "\(accountDir.lastPathComponent)/\(repoDir.lastPathComponent)"
                found.append(LocalRepo(
                    nameWithOwner: nameWithOwner,
                    path: repoDir,
                    sizeBytes: directorySize(repoDir)
                ))
            }
        }
        return found
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
