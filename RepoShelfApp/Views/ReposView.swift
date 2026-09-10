import SwiftUI
import AppKit

struct ReposView: View {
    @EnvironmentObject private var store: Store
    @Binding var query: String
    @Binding var clonedOnly: Bool
    let onClone: (RepoRow) -> Void
    let onAddRepo: () -> Void

    /// When true (the default), the list is limited to repos RepoShelf has
    /// touched — cloned, opened, or added. Browsing the full account list is
    /// behind a CTA so hundreds of untouched repos don't bury the ones in use.
    @State private var recentOnly = true

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var isSearching: Bool { !trimmedQuery.isEmpty }

    private func matchesQuery(_ row: RepoRow) -> Bool {
        let q = trimmedQuery
        return q.isEmpty
            || row.name.lowercased().contains(q)
            || row.remote.nameWithOwner.lowercased().contains(q)
    }

    /// Recent view works off everything (incl. clones detected on disk);
    /// browse-all works off just the active account's list.
    private var matchingRows: [RepoRow] {
        let source = (!recentOnly && !isSearching) ? store.browseRows : store.rows
        return source.filter { matchesQuery($0) && (!clonedOnly || $0.isCloned) }
    }

    /// Rows the user has interacted with (or that are on disk), most-recent first.
    private var recentRows: [RepoRow] {
        let keys = store.interactedRepoKeys
        return matchingRows
            .filter { keys.contains($0.id) || $0.isCloned }
            .sorted { lhs, rhs in
                let l = store.state.lastOpened[lhs.id] ?? .distantPast
                let r = store.state.lastOpened[rhs.id] ?? .distantPast
                if l != r { return l > r }
                return (lhs.remote.pushedAt ?? .distantPast) > (rhs.remote.pushedAt ?? .distantPast)
            }
    }

    /// What the list actually shows: search hits cut across everything;
    /// otherwise the recent set unless the user chose to browse all.
    private var visibleRows: [RepoRow] {
        if isSearching || !recentOnly {
            return matchingRows.sorted { ($0.remote.pushedAt ?? .distantPast) > ($1.remote.pushedAt ?? .distantPast) }
        }
        return recentRows
    }

    private var hiddenCount: Int {
        max(0, store.browseRows.count - recentRows.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    TextField("Filter repos", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))

                Button {
                    clonedOnly.toggle()
                } label: {
                    Text("On disk")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(clonedOnly ? Color.white : Color.secondary)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(clonedOnly ? Theme.accent : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(clonedOnly ? Theme.accent : Theme.border))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.hitFull)

                Button(action: onAddRepo) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.hitFull)
                .help("Add a repo by URL")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if let message = store.errorMessage {
                ErrorBanner(message: message)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }

            if !isSearching && recentOnly && !store.unclonedRepoFolders.isEmpty {
                UnclonedFoldersCard(folders: store.unclonedRepoFolders)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }

            if isSearching {
                listCaption("Searching all repos for \(store.activeLogin)")
            } else if !recentOnly {
                HStack {
                    listCaption("All repos for \(store.activeLogin)")
                    Spacer(minLength: 0)
                    Button { recentOnly = true } label: {
                        Text("Show recent only")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.vertical, 3).padding(.leading, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.hitFull)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
            }

            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(visibleRows) { row in
                        RepoRowView(row: row, onClone: { onClone(row) })
                    }

                    if visibleRows.isEmpty {
                        EmptyHint(text: emptyText)
                    }

                    if !isSearching && recentOnly && hiddenCount > 0 {
                        Button {
                            recentOnly = false
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.stack.3d.up")
                                Text("Browse all \(matchingRows.count) repos")
                                    .fontWeight(.semibold)
                                Text("· \(hiddenCount) older")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.hitFull)
                        .padding(.top, 3)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
    }

    private func listCaption(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
    }

    private var emptyText: String {
        if store.isLoadingRepos { return "Loading repos…" }
        if isSearching { return "No repos match “\(query)”." }
        if recentOnly { return "No repos touched yet — clone one from Browse all, or add by URL with +." }
        return "Nothing here — use + to add a repo by URL."
    }
}

private struct RepoRowView: View {
    @EnvironmentObject private var store: Store
    let row: RepoRow
    let onClone: () -> Void

    private var rowTag: String? {
        if row.isLocalOnly { return "LOCAL ONLY" }
        if row.isDetected { return "DETECTED" }
        if row.remote.isManuallyAdded { return "ADDED" }
        return nil
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.isLocalOnly || row.isDetected ? row.remote.nameWithOwner : row.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if row.remote.isPrivate {
                        Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                    if let tag = rowTag {
                        Text(tag)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.border))
                    }
                }
                HStack(spacing: 8) {
                    if row.isCloned {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                            Text("on disk · \(row.sizeText ?? "?")\(row.strategy.map { " · \($0.title.lowercased())" } ?? "")")
                        }
                        .foregroundStyle(Theme.ok)
                        .fontWeight(.semibold)
                    } else {
                        Text(row.remote.pushedAt == nil ? "—" : "pushed \(Formatting.relative(row.remote.pushedAt))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 10.5))

                if row.isCloned, let path = row.pathText {
                    Text(path)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)

            if row.isBusy {
                ProgressView().controlSize(.small)
            } else if row.isCloned {
                HStack(spacing: 4) {
                    IconActionButton(systemName: "chevron.left.forwardslash.chevron.right", tint: Theme.accent) {
                        store.openInEditor(row.id)
                    }
                    IconActionButton(systemName: "folder") { store.revealInFinder(row.id) }
                    IconActionButton(systemName: "trash", tint: Theme.danger, borderColor: Theme.dangerBorder) {
                        store.remove(row.id)
                    }
                }
            } else if !row.isLocalOnly {
                Button(action: onClone) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 11, weight: .bold))
                        Text("Download").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Theme.accent))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.hitFull)
                .help(row.strategy != nil ? "Re-download this repo" : "Clone this repo")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(row.isCloned ? Theme.okBorder : Theme.borderSoft))
    }
}

/// Folders that match a repo name but aren't git checkouts.
private struct UnclonedFoldersCard: View {
    let folders: [(name: String, url: URL)]
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.folder").font(.system(size: 11))
                    Text("\(folders.count) folder\(folders.count == 1 ? "" : "s") match your repos but aren't git clones")
                        .font(.system(size: 10.5, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.hitFull)

            if expanded {
                ForEach(folders, id: \.url) { folder in
                    HStack(spacing: 6) {
                        Text(folder.name).font(.system(size: 10.5, weight: .medium))
                        Text(folder.url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.system(size: 9.5)).foregroundStyle(.tertiary)
                            .lineLimit(1).truncationMode(.head)
                        Spacer(minLength: 0)
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([folder.url])
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.hitFull)
                        .help("Reveal in Finder")
                    }
                }
                Text("These are plain copies — `git init` in place, or clone fresh and delete the copy.")
                    .font(.system(size: 9.5)).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surfaceSecondary))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderSoft))
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
            Text(message).font(.system(size: 10.5)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.danger)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.dangerBackground))
    }
}
