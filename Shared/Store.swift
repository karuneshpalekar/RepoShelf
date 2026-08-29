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
}

@MainActor
final class Store: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published var activeLogin: String = ""
    @Published private(set) var remoteRepos: [String: [RemoteRepo]] = [:]   // login -> repos
    @Published private(set) var localRepos: [String: LocalRepo] = [:]        // nameWithOwner -> clone
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
        guard let data = try? Data(contentsOf: SharedStorage.stateURL),
              let decoded = try? JSONDecoder().decode(RepoShelfState.self, from: data) else { return }
        state = decoded
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

    // MARK: Local scan

    func scanLocal() async {
        isScanning = true
        defer { isScanning = false }
        let root = state.workspaceRoot
        let clones = await Task.detached { GitHub.scanClones(root: root) }.value
        var map: [String: LocalRepo] = [:]
        for clone in clones { map[clone.nameWithOwner] = clone }
        localRepos = map
    }

    // MARK: Derived rows

    /// Rows for the active account: its `gh repo list` plus any manually
    /// added repos assigned to it.
    var rows: [RepoRow] {
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
        return remotes.map { remote in
            RepoRow(
                remote: remote,
                local: localRepos[remote.nameWithOwner],
                strategy: state.cloneStrategies[remote.nameWithOwner],
                isBusy: busyRepos.contains(remote.nameWithOwner)
            )
        }
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
        return state.workspaceRoot.appendingPathComponent(owner).appendingPathComponent(repo)
    }

    func estimatedBytes(for row: RepoRow, strategy: CloneStrategy) -> Int64 {
        let kb = row.remote.diskUsageKB > 0 ? row.remote.diskUsageKB : 40_000
        return Int64(Double(kb) * 1024 * strategy.sizeFactor)
    }

    func clone(_ row: RepoRow, strategy: CloneStrategy) {
        let slug = row.remote.nameWithOwner
        let dest = destination(for: slug)
        busyRepos.insert(slug)
        Task {
            defer { busyRepos.remove(slug) }
            do {
                let token = try await token(for: activeLogin)
                try await GitHub.clone(
                    slug: slug, into: dest, strategy: strategy,
                    token: token, identity: activeIdentity
                )
                state.cloneStrategies[slug] = strategy
                state.lastOpened[slug] = Date()
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
        guard let local = localRepos[nameWithOwner] else { return }
        let freed = Formatting.size(bytes: local.sizeBytes)
        let name = nameWithOwner.split(separator: "/").last.map(String.init) ?? nameWithOwner
        busyRepos.insert(nameWithOwner)
        Task {
            defer { busyRepos.remove(nameWithOwner) }
            do {
                try FileManager.default.trashItem(at: local.path, resultingItemURL: nil)
                state.lastOpened[nameWithOwner] = nil
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
            persist()
            errorMessage = nil
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
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
        guard let local = localRepos[nameWithOwner] else { return }
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
        guard let local = localRepos[nameWithOwner] else { return }
        NSWorkspace.shared.activateFileViewerSelecting([local.path])
    }
}
