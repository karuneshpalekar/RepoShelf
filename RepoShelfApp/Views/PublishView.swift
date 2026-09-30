import SwiftUI
import AppKit

struct PublishView: View {
    @EnvironmentObject private var store: Store
    let onPublish: (URL) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                Text("Put a local folder on GitHub — RepoShelf runs `git init` if needed, makes the first commit, creates the repo, and pushes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    chooseFolder()
                } label: {
                    Label("Choose a folder…", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let message = store.errorMessage {
                    ErrorBanner(message: message)
                }

                if !store.localOnlyRepos.isEmpty {
                    Text("GIT REPOS WITH NO REMOTE")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)

                    ForEach(store.localOnlyRepos, id: \.path) { repo in
                        row(name: repo.path.lastPathComponent, url: repo.path)
                    }
                }

                Text("Anything else — a plain project folder that was never a git repo — add it with Choose a folder above.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(14)
        }
    }

    private func row(name: String, url: URL) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).fontWeight(.medium)
                Text(url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
            }
            Spacer(minLength: 0)
            if store.publishingPaths.contains(url.path) {
                ProgressView().controlSize(.small)
            } else {
                Button("Publish") { onPublish(url) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 10)
        .cardStyle(radius: 9)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK, let url = panel.url {
            onPublish(url)
        }
    }
}
