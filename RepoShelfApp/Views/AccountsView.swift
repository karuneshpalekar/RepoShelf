import SwiftUI

struct AccountsView: View {
    @EnvironmentObject private var store: Store
    let onAddAccount: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                ForEach(store.accounts) { account in
                    AccountCard(account: account)
                }

                Button {
                    onAddAccount()
                } label: {
                    Label("Add account", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Text("runs `gh auth login` in a terminal, then remembers the commit identity")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(14)
        }
    }
}

private struct AccountCard: View {
    @EnvironmentObject private var store: Store
    let account: Account

    @State private var name = ""
    @State private var email = ""

    private var isActive: Bool { account.login == store.activeLogin }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                AccountAvatar(login: account.login, size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.login).fontWeight(.medium)
                    Text(email.isEmpty ? "no commit email set" : email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isActive {
                    TagBadge(text: "ACTIVE", tag: .active)
                } else {
                    Button("Switch") { store.setActive(account.login) }
                        .buttonStyle(.link)
                }
            }

            VStack(spacing: 6) {
                LabeledField(label: "commit name", text: $name, placeholder: account.login)
                LabeledField(label: "commit email", text: $email, placeholder: "\(account.login)@users.noreply.github.com")
            }

            Text("Clones from this account commit with the identity above, regardless of your global ~/.gitconfig.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .cardStyle(radius: 9)
        .onAppear { syncFromStore() }
        .onChange(of: name) { _, _ in commit() }
        .onChange(of: email) { _, _ in commit() }
    }

    private func syncFromStore() {
        let identity = store.identity(for: account.login)
        name = identity.name
        email = identity.email
    }

    private func commit() {
        store.setIdentity(GitIdentity(name: name, email: email), for: account.login)
    }
}

struct LabeledField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
