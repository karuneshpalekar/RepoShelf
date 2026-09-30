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
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Filter repos", text: $query)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .frame(width: 200, height: 26)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))

                FilterChip(title: "On disk", selected: clonedOnly) {
                    withAnimation(Motion.swap) { clonedOnly.toggle() }
                }

                Button(action: onAddRepo) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add a repo by URL")

                Spacer(minLength: 0)
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
                    Button("Show recent only") { withAnimation(Motion.swap) { recentOnly = true } }
                        .buttonStyle(.link)
                        .font(.caption)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
            }

            if visibleRows.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 7) {
                        ForEach(visibleRows) { row in
                            RepoRowView(row: row, onClone: { onClone(row) })
                        }

                        if !isSearching && recentOnly && hiddenCount > 0 {
                            Button {
                                withAnimation(Motion.swap) { recentOnly = false }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.stack.3d.up")
                                    Text("Browse all \(matchingRows.count) repos")
                                    Text("· \(hiddenCount) older").foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 3)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func listCaption(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.isLoadingRepos {
            ProgressView("Loading repos…")
        } else if isSearching {
            ContentUnavailableView.search(text: query)
        } else if recentOnly {
            ContentUnavailableView(
                "No repos touched yet", systemImage: "tray",
                description: Text("Clone one from Browse all, or add by URL with +.")
            )
        } else {
            ContentUnavailableView(
                "Nothing here", systemImage: "tray",
                description: Text("Add a repo by URL with +.")
            )
        }
    }
}

private struct RepoRowView: View {
    @EnvironmentObject private var store: Store
    let row: RepoRow
    let onClone: () -> Void

    private var tag: (String, Tag)? {
        if row.isLocalOnly { return ("LOCAL ONLY", .info) }
        if row.isDetected { return ("DETECTED", .info) }
        if row.remote.isManuallyAdded { return ("ADDED", .info) }
        return nil
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.isLocalOnly || row.isDetected ? row.remote.nameWithOwner : row.name)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if row.remote.isPrivate {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                    if let (text, tagColor) = tag {
                        TagBadge(text: text, tag: tagColor)
                    }
                }
                HStack(spacing: 8) {
                    if row.isCloned {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark").font(.caption2.weight(.bold))
                            Text("on disk · \(row.sizeText ?? "?")\(row.strategy.map { " · \($0.title.lowercased())" } ?? "")")
                        }
                        .foregroundStyle(.green)
                        .fontWeight(.medium)
                    } else {
                        Text(row.remote.pushedAt == nil ? "—" : "pushed \(Formatting.relative(row.remote.pushedAt))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)

                if row.isCloned, let path = row.pathText {
                    Text(path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)

            if row.isBusy {
                ProgressView().controlSize(.small)
            } else if row.isCloned {
                HStack(spacing: 2) {
                    Button {
                        store.openInEditor(row.id)
                    } label: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                    }
                    .help("Open in editor")

                    Button {
                        store.revealInFinder(row.id)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Show in Finder")

                    Button {
                        store.remove(row.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .foregroundStyle(.red)
                    .help("Move the local copy to the Trash")
                }
                .buttonStyle(.borderless)
            } else if !row.isLocalOnly {
                Button(action: onClone) {
                    Text("Download")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help(row.strategy != nil ? "Re-download this repo" : "Clone this repo")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .cardStyle(radius: 9)
    }
}

/// Folders that match a repo name but aren't git checkouts.
private struct UnclonedFoldersCard: View {
    let folders: [(name: String, url: URL)]
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(folders, id: \.url) { folder in
                    HStack(spacing: 6) {
                        Text(folder.name).fontWeight(.medium)
                        Text(folder.url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1).truncationMode(.head)
                        Spacer(minLength: 0)
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([folder.url])
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        .help("Show in Finder")
                    }
                }
                Text("These are plain copies — `git init` in place, or clone fresh and delete the copy.")
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
            .padding(.top, 6)
        } label: {
            Label(
                "\(folders.count) folder\(folders.count == 1 ? "" : "s") match your repos but aren't git clones",
                systemImage: "questionmark.folder"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(9)
        .cardStyle(radius: 8)
    }
}
