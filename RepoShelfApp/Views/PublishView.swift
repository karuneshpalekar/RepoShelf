import SwiftUI
import AppKit

struct PublishView: View {
    @EnvironmentObject private var store: Store
    let onPublish: (URL) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                Text("Put a local folder on GitHub — RepoShelf runs `git init` if needed, makes the first commit, creates the repo, and pushes.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    chooseFolder()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                        Text("Choose a folder…").fontWeight(.semibold)
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                )

                if let message = store.errorMessage {
                    ErrorBanner(message: message)
                }

                if !store.localOnlyRepos.isEmpty {
                    Text("GIT REPOS WITH NO REMOTE")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)

                    ForEach(store.localOnlyRepos, id: \.path) { repo in
                        row(name: repo.path.lastPathComponent, url: repo.path, hasHistory: true)
                    }
                }

                Text("Anything else — a plain project folder that was never a git repo — add it with Choose a folder above.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(14)
        }
    }

    private func row(name: String, url: URL, hasHistory: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 12.5, weight: .semibold))
                Text(url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
            }
            Spacer(minLength: 0)
            if store.publishingPaths.contains(url.path) {
                ProgressView().controlSize(.small)
            } else {
                Button { onPublish(url) } label: {
                    Text("Publish").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.accent))
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.borderSoft))
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
