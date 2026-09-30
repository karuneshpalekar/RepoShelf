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
                Text("Publish to GitHub").font(.title3.weight(.semibold))
                Text(folderPath.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
            }

            VStack(spacing: 8) {
                LabeledField(label: "repo name", text: $name, placeholder: folder.lastPathComponent)

                HStack(spacing: 8) {
                    Text("account")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 78, alignment: .leading)
                    Menu {
                        ForEach(store.accounts) { account in
                            Button(account.login) { owner = account.login }
                        }
                    } label: {
                        Label(owner.isEmpty ? "—" : owner, systemImage: "person.crop.circle.fill")
                            .foregroundStyle(owner.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(AccountPalette.color(owner)))
                    }
                    .menuStyle(.borderlessButton)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                    .fixedSize()
                    Spacer(minLength: 0)
                }

                LabeledField(label: "description", text: $description, placeholder: "optional")
            }

            Picker("Visibility", selection: $isPrivate) {
                Label("Private", systemImage: "lock.fill").tag(true)
                Label("Public", systemImage: "globe").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if needsInit {
                Label("Not a git repo yet — RepoShelf will run git init and commit every file in the folder first.",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel", action: dismiss).keyboardShortcut(.cancelAction)
                Button(isPrivate ? "Create private repo" : "Create public repo") {
                    store.publish(
                        folder: folder,
                        owner: owner,
                        name: name.trimmingCharacters(in: .whitespaces).isEmpty ? folder.lastPathComponent : name.trimmingCharacters(in: .whitespaces),
                        description: description,
                        isPrivate: isPrivate
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(owner.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 400)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
        .shadow(radius: 24, y: 8)
        .onAppear {
            if name.isEmpty { name = folder.lastPathComponent }
            if owner.isEmpty { owner = store.activeLogin }
        }
    }
}
