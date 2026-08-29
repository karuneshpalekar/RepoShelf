import SwiftUI

struct ReposView: View {
    @EnvironmentObject private var store: Store
    @Binding var query: String
    @Binding var clonedOnly: Bool
    let onClone: (RepoRow) -> Void
    let onAddRepo: () -> Void

    private var filteredRows: [RepoRow] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return store.rows.filter { row in
            (q.isEmpty || row.name.lowercased().contains(q) || row.remote.nameWithOwner.lowercased().contains(q))
            && (!clonedOnly || row.isCloned)
        }
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
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 8).fill(clonedOnly ? Theme.accent : Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(clonedOnly ? Theme.accent : Theme.border))

                Button(action: onAddRepo) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                .help("Add a repo by URL")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if let message = store.errorMessage {
                ErrorBanner(message: message)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }

            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(filteredRows) { row in
                        RepoRowView(row: row, onClone: { onClone(row) })
                    }
                    if filteredRows.isEmpty {
                        EmptyHint(text: store.isLoadingRepos
                            ? "Loading repos…"
                            : "Nothing here — use + to add a repo by URL.")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
    }
}

private struct RepoRowView: View {
    @EnvironmentObject private var store: Store
    let row: RepoRow
    let onClone: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    if row.remote.isPrivate {
                        Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                    if row.remote.isManuallyAdded {
                        Text("ADDED")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.border))
                    }
                }
                HStack(spacing: 8) {
                    Text(row.remote.pushedAt == nil ? "—" : "pushed \(Formatting.relative(row.remote.pushedAt))")
                        .foregroundStyle(.secondary)
                    if row.isCloned {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                            Text("on disk · \(row.sizeText ?? "?")\(row.strategy.map { " · \($0.title.lowercased())" } ?? "")")
                        }
                        .foregroundStyle(Theme.ok)
                        .fontWeight(.semibold)
                    }
                }
                .font(.system(size: 10.5))
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
            } else {
                Button(action: onClone) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.to.line").font(.system(size: 10, weight: .bold))
                        Text("Clone").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.accent))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(row.isCloned ? Theme.okBorder : Theme.borderSoft))
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
