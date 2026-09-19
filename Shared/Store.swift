import Foundation
import AppKit
import Combine

/// A repo as shown in the Repos list: remote metadata plus whatever is
/// known about a local clone.
struct RepoRow: Identifiable {
    var id: String { remote.nameWithOwner }
    var remote: RemoteRepo
    var local: LocalRepo?
    var strategy: CloneStrategy?
    var isBusy: Bool

    var isCloned: Bool { local != nil }
    var name: String { remote.name }
    var sizeText: String? { local.map { Formatting.size(bytes: $0.sizeBytes) } }

    /// Found on disk but not in the active account's repo list.
    var isDetected: Bool { remote.isDetectedLocal }
    /// A git working copy with no GitHub origin — can't be re-cloned.
    var isLocalOnly: Bool { local?.isLocalOnly ?? remote.nameWithOwner.hasPrefix("local/") }
    /// Where the clone lives, shortened with ~, when on disk.
    var pathText: String? {
        local.map { $0.path.path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
    }
}

@MainActor
final class Store: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published var activeLogin: String = ""
    @Published private(set) var remoteRepos: [String: [RemoteRepo]] = [:]   // login -> repos
    @Published private(set) var localRepos: [String: LocalRepo] = [:]        // nameWithOwner -> clone
    @Published private(set) var looseFolders: [URL] = []                     // project-looking folders that aren't git checkouts
    @Published private(set) var detectedMeta: [String: RemoteRepo] = [:]     // slug -> gh metadata for clones outside the active list
    @Published private(set) var state = RepoShelfState()

    @Published var isLoadingRepos = false
    @Published var isScanning = false
    @Published var busyRepos: Set<String> = []
    @Published var errorMessage: String?

    private var tokenCache: [String: String] = [:]
    private var reposLoadedFor: Set<String> = []

    // MARK: Lifecycle

    init() {
        load()
    }

    func bootstrap() {
        Task { await refreshAccounts() }
    }

    // MARK: Persistence

    private func load() {
        if let data = try? Data(contentsOf: SharedStorage.stateURL),
           let decoded = try? JSONDecoder().decode(RepoShelfState.self, from: data) {
            state = decoded
        }
        if state.scanRootPaths.isEmpty {
            state.scanRootPaths = SharedStorage.defaultScanRoots
                .filter { FileManager.default.fileExists(atPath: $0.path) }
                .map { $0.path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
        }
        // Drop duplicates that differ only by case (case-insensitive FS).
        var seen = Set<String>()
        let deduped = state.scanRootPaths.filter {
            let key = ($0 as NSString).expandingTildeInPath.lowercased()
            return seen.insert(key).inserted
        }
        if deduped != state.scanRootPaths { state.scanRootPaths = deduped }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: SharedStorage.stateURL, options: .atomic)
        } catch {
            print("RepoShelf: failed to persist state: \(error)")
        }
    }

    func log(_ kind: ActivityEvent.Kind, _ subject: String, _ detail: String) {
        state.activity.insert(ActivityEvent(kind: kind, subject: subject, detail: detail), at: 0)
        state.activity = Array(state.activity.prefix(200))
        persist()
    }

    // MARK: Accounts

    func token(for login: String) async throws -> String {
        if let cached = tokenCache[login] { return cached }
        let token = try await GitHub.token(for: login)
        tokenCache[login] = token
        return token
    }

    func refreshAccounts() async {
        do {
            let fetched = try await GitHub.accounts()
            accounts = fetched
            if activeLogin.isEmpty || !fetched.contains(where: { $0.login == activeLogin }) {
                activeLogin = fetched.first(where: { $0.isActive })?.login ?? fetched.first?.login ?? ""
            }
            errorMessage = nil
            if !activeLogin.isEmpty {
                await loadReposIfNeeded(for: activeLogin)
            }
            await scanLocal()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func setActive(_ login: String) {
        guard login != activeLogin else { return }
        activeLogin = login
        log(.switchAccount, login, "active account")
        Task { await loadReposIfNeeded(for: login) }
    }

    var activeIdentity: GitIdentity? {
        state.identities[activeLogin]
    }

    func identity(for login: String) -> GitIdentity {
        state.identities[login] ?? GitIdentity(name: "", email: "")
    }

    func setIdentity(_ identity: GitIdentity, for login: String) {
        state.identities[login] = identity
        persist()
    }

    // MARK: Repo listing

    func loadReposIfNeeded(for login: String, force: Bool = false) async {
        guard !login.isEmpty else { return }
        if !force, reposLoadedFor.contains(login) { return }
        isLoadingRepos = true
        defer { isLoadingRepos = false }
        do {
            let token = try await token(for: login)
            let repos = try await GitHub.repos(for: login, token: token)
            remoteRepos[login] = repos
            reposLoadedFor.insert(login)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func refreshCurrent() {
        Task {
            await refreshAccounts()
            await loadReposIfNeeded(for: activeLogin, force: true)
        }
    }

    // MARK: Scan folders

    /// Folders actually scanned — the user's list plus the workspace root
    /// (so freshly cloned repos are re-discovered), deduped.
    var scanRoots: [URL] {
        var urls = state.scanRootPaths.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        urls.append(state.workspaceRoot)
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path.lowercased()).inserted }
    }

    func addScanRoot(_ url: URL) {
        let display = url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        guard !state.scanRootPaths.contains(display), !state.scanRootPaths.contains(url.path) else { return }
        state.scanRootPaths.append(display)
        persist()
        Task { await scanLocal() }
    }

    func removeScanRoot(_ path: String) {
        state.scanRootPaths.removeAll { $0 == path }
        persist()
        Task { await scanLocal() }
    }

    // MARK: Local scan

    func scanLocal() async {
        isScanning = true
        defer { isScanning = false }
        let roots = scanRoots
        let result = await Task.detached { GitHub.scan(roots: roots) }.value
        var map: [String: LocalRepo] = [:]
        for clone in result.clones {
            map[clone.nameWithOwner] = clone
            if let slug = clone.originSlug {
                rememberRepo(slug, url: clone.originURL ?? "", parent: clone.path.deletingLastPathComponent())
            }
        }
        localRepos = map
        looseFolders = result.looseDirs
        await enrichDetectedClones()
    }

    /// Folders that share a name with one of your repos but aren't git
    /// checkouts — i.e. a copy of the project that was never `git clone`d.
    var unclonedRepoFolders: [(name: String, url: URL)] {
        let repoNames = Set(remoteRepos.values.flatMap { $0 }.map { $0.name.lowercased() })
        let clonedNames = Set(localRepos.keys.compactMap { $0.split(separator: "/").last?.lowercased() })
        var seen = Set<String>()
        return looseFolders
            .filter { url in
                let n = url.lastPathComponent.lowercased()
                return repoNames.contains(n) && !clonedNames.contains(n) && seen.insert(n).inserted
            }
            .map { (name: $0.lastPathComponent, url: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// For clones whose `owner/repo` isn't in any loaded `gh repo list`, pull
    /// the repo's real metadata (push date, visibility) so its row looks like
    /// any other — not a bare folder.
    private func enrichDetectedClones() async {
        guard !activeLogin.isEmpty else { return }
        let listed = Set(remoteRepos.values.flatMap { $0 }.map(\.nameWithOwner))
        let candidates = localRepos.values.compactMap { $0.originSlug } + state.knownRepos.map(\.nameWithOwner)
        let pending = Array(Set(candidates))
            .filter { $0.contains("/") && !listed.contains($0) && detectedMeta[$0] == nil }
        guard !pending.isEmpty, let token = try? await token(for: activeLogin) else { return }
        for slug in pending {
            if var view = try? await GitHub.repoView(slug: slug, token: token) {
                view.isDetectedLocal = true
                view.isManuallyAdded = false
                detectedMeta[slug] = view
            }
        }
    }

    // MARK: Derived rows

    /// The name GitHub currently knows a repo by. Repos get renamed / moved
    /// between orgs, so an old `origin` slug (Ayurwell-v1/x) and the current
    /// one (Ayurgrroove/x) must collapse to a single row.
    func canonicalKey(_ key: String) -> String {
        detectedMeta[key]?.nameWithOwner ?? key
    }

    /// The on-disk clone for a row id, whichever slug form it was found under.
    func localRepo(for id: String) -> LocalRepo? {
        if let hit = localRepos[id] { return hit }
        return localRepos.first { canonicalKey($0.key) == id }?.value
    }

    private func makeRow(_ remote: RemoteRepo) -> RepoRow {
        RepoRow(
            remote: remote,
            local: localRepo(for: remote.nameWithOwner),
            strategy: state.cloneStrategies[remote.nameWithOwner],
            isBusy: busyRepos.contains(remote.nameWithOwner)
        )
    }

    /// The active account's `gh repo list` plus repos manually added to it —
    /// what "Browse all" shows.
    var browseRows: [RepoRow] {
        var remotes = remoteRepos[activeLogin] ?? []
        let added = state.addedRepos.filter { $0.login == activeLogin }
        for entry in added where !remotes.contains(where: { $0.nameWithOwner == entry.nameWithOwner }) {
            let name = entry.nameWithOwner.split(separator: "/").last.map(String.init) ?? entry.nameWithOwner
            remotes.append(RemoteRepo(
                name: name, nameWithOwner: entry.nameWithOwner, description: "",
                isPrivate: false, pushedAt: nil, url: entry.cloneURL, diskUsageKB: 0,
                isManuallyAdded: true
            ))
        }
        return remotes.map(makeRow)
    }

    /// Everything worth showing in the "recent" view: the browse set, plus
    /// every clone found on disk (any account / org), plus repos previously
    /// on disk that were cleaned up — so a Download button is always at hand.
    var rows: [RepoRow] {
        var out = browseRows
        var seen = Set(out.map(\.id))

        for (key, local) in localRepos {
            let canon = canonicalKey(key)
            guard seen.insert(canon).inserted else { continue }
            let remote = detectedMeta[key] ?? RemoteRepo(
                name: local.originSlug?.split(separator: "/").last.map(String.init) ?? local.path.lastPathComponent,
                nameWithOwner: canon, description: "", isPrivate: false, pushedAt: nil,
                url: local.originURL ?? "", diskUsageKB: 0,
                isManuallyAdded: false, isDetectedLocal: true
            )
            out.append(makeRow(remote))
        }

        for known in state.knownRepos {
            let canon = canonicalKey(known.nameWithOwner)
            guard seen.insert(canon).inserted else { continue }
            let remote = detectedMeta[known.nameWithOwner] ?? RemoteRepo(
                name: known.nameWithOwner.split(separator: "/").last.map(String.init) ?? known.nameWithOwner,
                nameWithOwner: canon, description: "", isPrivate: false, pushedAt: nil,
                url: known.cloneURL, diskUsageKB: 0,
                isManuallyAdded: false, isDetectedLocal: true
            )
            out.append(makeRow(remote))
        }
        return out
    }

    /// Repo keys the user has interacted with — cloned now, opened before,
    /// added, or seen on disk at some point. Drives the "recent" view.
    var interactedRepoKeys: Set<String> {
        var keys = Set(localRepos.keys)
        keys.formUnion(state.lastOpened.keys)
        keys.formUnion(state.addedRepos.map(\.nameWithOwner))
        keys.formUnion(state.knownRepos.map(\.nameWithOwner))
        keys.formUnion(keys.map { canonicalKey($0) })
        return keys
    }

    /// The account whose token should fetch `login`'s repos.
    private func tokenAccount(for login: String) -> String {
        accounts.contains { $0.login == login } ? login : activeLogin
    }

    private func ownerOf(_ slug: String) -> String {
        String(slug.split(separator: "/").first ?? Substring(activeLogin))
    }

    func rememberRepo(_ nameWithOwner: String, url: String, parent: URL?) {
        guard !nameWithOwner.hasPrefix("local/"), nameWithOwner.contains("/") else { return }
        let parentDisplay = parent?.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        if let i = state.knownRepos.firstIndex(where: { $0.nameWithOwner == nameWithOwner }) {
            if !url.isEmpty { state.knownRepos[i].cloneURL = url }
            if let parentDisplay { state.knownRepos[i].lastParentPath = parentDisplay }
        } else {
            state.knownRepos.append(RepoShelfState.KnownRepo(
                nameWithOwner: nameWithOwner, cloneURL: url,
                login: ownerOf(nameWithOwner), lastParentPath: parentDisplay
            ))
        }
        persist()
    }

    /// Cloned repos (any account) not opened in 21+ days.
    var staleClones: [LocalRepo] {
        let cutoff = Date().addingTimeInterval(-21 * 86_400)
        return localRepos.values
            .filter { (state.lastOpened[$0.nameWithOwner] ?? .distantPast) < cutoff }
            .sorted { $0.sizeBytes > $1.sizeBytes }
    }

    var workspaceBytes: Int64 {
        localRepos.values.reduce(0) { $0 + $1.sizeBytes }
    }

    var freeDiskBytes: Int64 {
        let values = try? SharedStorage.directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    // MARK: Clone / remove

    func destination(for slug: String) -> URL {
        let parts = slug.split(separator: "/")
        let owner = parts.first.map(String.init) ?? activeLogin
        let repo = parts.last.map(String.init) ?? slug
        // Re-download back to where the clone last lived, if we know.
        if let known = state.knownRepos.first(where: { $0.nameWithOwner == slug }),
           let parent = known.lastParentPath, !parent.isEmpty {
            return URL(fileURLWithPath: (parent as NSString).expandingTildeInPath)
                .appendingPathComponent(repo)
        }
        return state.workspaceRoot.appendingPathComponent(owner).appendingPathComponent(repo)
    }

    func estimatedBytes(for row: RepoRow, strategy: CloneStrategy) -> Int64 {
        let kb = row.remote.diskUsageKB > 0 ? row.remote.diskUsageKB : 40_000
        return Int64(Double(kb) * 1024 * strategy.sizeFactor)
    }

    func clone(_ row: RepoRow, strategy: CloneStrategy) {
        let slug = row.remote.nameWithOwner
        let dest = destination(for: slug)
        let account = tokenAccount(for: ownerOf(slug))
        busyRepos.insert(slug)
        Task {
            defer { busyRepos.remove(slug) }
            do {
                let token = try await token(for: account)
                try await GitHub.clone(
                    slug: slug, into: dest, strategy: strategy,
                    token: token, identity: state.identities[account]
                )
                state.cloneStrategies[slug] = strategy
                state.lastOpened[slug] = Date()
                rememberRepo(slug, url: row.remote.url, parent: dest.deletingLastPathComponent())
                persist()
                await scanLocal()
                let size = localRepos[slug].map { Formatting.size(bytes: $0.sizeBytes) } ?? "cloned"
                log(.clone, row.name, "\(strategy.title.lowercased()) · \(size)")
                errorMessage = nil
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func remove(_ nameWithOwner: String) {
        guard let local = localRepo(for: nameWithOwner) else { return }
        let freed = Formatting.size(bytes: local.sizeBytes)
        let name = nameWithOwner.split(separator: "/").last.map(String.init) ?? nameWithOwner
        busyRepos.insert(nameWithOwner)
        Task {
            defer { busyRepos.remove(nameWithOwner) }
            do {
                try FileManager.default.trashItem(at: local.path, resultingItemURL: nil)
                // Keep lastOpened so the repo stays in the Repos "recent" list
                // with a Clone button — removing frees disk, not the shortcut.
                persist()
                await scanLocal()
                log(.remove, name, "freed \(freed)")
                errorMessage = nil
            } catch {
                errorMessage = "Couldn't remove \(name): \(error.localizedDescription)"
            }
        }
    }

    func removeAllStale() {
        for clone in staleClones { remove(clone.nameWithOwner) }
    }

    // MARK: Add repo

    func addRepo(from input: String) async -> Bool {
        guard let slug = GitHub.parseSlug(input) else {
            errorMessage = "Enter a GitHub URL or owner/name."
            return false
        }
        do {
            let token = try await token(for: activeLogin)
            let view = try await GitHub.repoView(slug: slug, token: token)
            state.addedRepos.removeAll { $0.nameWithOwner == view.nameWithOwner }
            state.addedRepos.append(RepoShelfState.AddedRepo(
                nameWithOwner: view.nameWithOwner, cloneURL: view.url, login: activeLogin
            ))
            remoteRepos[activeLogin, default: []].removeAll { $0.nameWithOwner == view.nameWithOwner }
            remoteRepos[activeLogin, default: []].insert(view, at: 0)
            rememberRepo(view.nameWithOwner, url: view.url, parent: nil)
            persist()
            errorMessage = nil
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    // MARK: Publish a local folder to GitHub

    /// Git working copies found on disk that have no GitHub origin.
    var localOnlyRepos: [LocalRepo] {
        localRepos.values.filter { $0.isLocalOnly }
            .sorted { $0.path.lastPathComponent.localizedCaseInsensitiveCompare($1.path.lastPathComponent) == .orderedAscending }
    }

    func folderIsGitRepo(_ url: URL) -> Bool { GitHub.isGitRepo(url) }

    var publishingPaths: Set<String> = []

    func publish(folder: URL, owner: String, name: String, description: String, isPrivate: Bool) {
        let key = folder.path
        guard !publishingPaths.contains(key) else { return }
        publishingPaths.insert(key)
        Task {
            defer { publishingPaths.remove(key) }
            do {
                let token = try await token(for: owner)
                try await GitHub.publish(
                    folder: folder, owner: owner, name: name,
                    description: description, isPrivate: isPrivate,
                    token: token, identity: state.identities[owner]
                )
                // Make sure the freshly published folder is scanned.
                let display = folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
                let covered = scanRoots.contains { folder.path.hasPrefix($0.standardizedFileURL.path) }
                if !covered, !state.scanRootPaths.contains(display) {
                    state.scanRootPaths.append(display)
                }
                persist()
                reposLoadedFor.remove(owner)
                await loadReposIfNeeded(for: owner, force: true)
                await scanLocal()
                log(.publish, "\(owner)/\(name)", isPrivate ? "private" : "public")
                errorMessage = nil
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: Add account

    func openTerminalForLogin() {
        guard let osa = Shell.locate("osascript") else {
            errorMessage = "Couldn't find osascript to open Terminal. Run `gh auth login` yourself."
            return
        }
        let script = "tell application \"Terminal\"\nactivate\ndo script \"gh auth login\"\nend tell"
        Task {
            _ = try? await Shell.run(osa, ["-e", script])
        }
    }

    // MARK: Editor / Finder

    func openInEditor(_ nameWithOwner: String) {
        guard let local = localRepo(for: nameWithOwner) else { return }
        state.lastOpened[nameWithOwner] = Date()
        persist()
        if let code = Shell.locate("code") {
            Task { _ = try? await Shell.run(code, [local.path.path]) }
        } else {
            NSWorkspace.shared.open(
                [local.path],
                withApplicationAt: URL(fileURLWithPath: "/Applications/Visual Studio Code.app"),
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    func revealInFinder(_ nameWithOwner: String) {
        guard let local = localRepo(for: nameWithOwner) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([local.path])
    }
}
