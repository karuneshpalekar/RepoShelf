import SwiftUI

struct AddAccountSheet: View {
    @EnvironmentObject private var store: Store
    let dismiss: () -> Void

    @State private var username = ""
    @State private var name = ""
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Add a GitHub account").font(.system(size: 13.5, weight: .bold))
                Text("Opens `gh auth login` in Terminal. These fields set the commit identity for its clones — you can also edit them later on the Accounts tab.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 7) {
                LabeledField(label: "username", text: $username, placeholder: "octocat")
                LabeledField(label: "commit name", text: $name, placeholder: "Octo Cat")
                LabeledField(label: "commit email", text: $email, placeholder: "octo@example.com")
            }

            Text("After you finish signing in in Terminal, hit Refresh in the menu-bar menu and the account appears here.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                SheetButton(title: "Cancel", action: dismiss)
                SheetButton(title: "Run gh auth login", kind: .primary) {
                    let login = username.trimmingCharacters(in: .whitespaces)
                    if !login.isEmpty {
                        store.setIdentity(GitIdentity(name: name, email: email), for: login)
                    }
                    store.openTerminalForLogin()
                    dismiss()
                }
            }
        }
        .padding(16)
        .frame(width: 400)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .shadow(radius: 24, y: 8)
    }
}
