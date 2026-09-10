import SwiftUI

struct PublishSheet: View {
    @EnvironmentObject private var store: Store
    let folderPath: String
    let dismiss: () -> Void

    @State private var name = ""
    @State private var owner = ""
    @State private var description = ""
    @State private var isPrivate = true

    private var folder: URL { URL(fileURLWithPath: folderPath) }
    private var needsInit: Bool { !store.folderIsGitRepo(folder) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Publish to GitHub").font(.system(size: 13.5, weight: .bold))
                Text(folderPath.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
            }

            VStack(spacing: 8) {
                LabeledField(label: "repo name", text: $name, placeholder: folder.lastPathComponent)

                HStack(spacing: 8) {
                    Text("account")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 78, alignment: .leading)
                    Menu {
                        ForEach(store.accounts) { account in
                            Button(account.login) { owner = account.login }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            AccountAvatar(login: owner, size: 14)
                            Text(owner.isEmpty ? "—" : owner).font(.system(size: 11.5, weight: .semibold))
                            Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.panelBackground))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
                        .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    Spacer(minLength: 0)
                }

                LabeledField(label: "description", text: $description, placeholder: "optional")
            }

            HStack(spacing: 8) {
                visibilityButton(title: "Private", symbol: "lock.fill", value: true)
                visibilityButton(title: "Public", symbol: "globe", value: false)
            }

            if needsInit {
                Label("Not a git repo yet — RepoShelf will run git init and commit every file in the folder first.",
                      systemImage: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                SheetButton(title: "Cancel", action: dismiss)
                SheetButton(
                    title: isPrivate ? "Create private repo" : "Create public repo",
                    kind: .primary,
                    isDisabled: owner.isEmpty
                ) {
                    store.publish(
                        folder: folder,
                        owner: owner,
                        name: name.trimmingCharacters(in: .whitespaces).isEmpty ? folder.lastPathComponent : name.trimmingCharacters(in: .whitespaces),
                        description: description,
                        isPrivate: isPrivate
                    )
                    dismiss()
                }
            }
        }
        .padding(16)
        .frame(width: 400)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .shadow(radius: 24, y: 8)
        .onAppear {
            if name.isEmpty { name = folder.lastPathComponent }
            if owner.isEmpty { owner = store.activeLogin }
        }
    }

    private func visibilityButton(title: String, symbol: String, value: Bool) -> some View {
        let selected = isPrivate == value
        return Button {
            isPrivate = value
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10))
                Text(title).font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(selected ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7).fill(selected ? Theme.accent : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(selected ? Theme.accent : Theme.border))
            .contentShape(Rectangle())
        }
        .buttonStyle(.hitFull)
    }
}
