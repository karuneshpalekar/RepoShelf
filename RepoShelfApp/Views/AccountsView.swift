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

                Button(action: onAddAccount) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add account").fontWeight(.semibold)
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                )

                Text("runs `gh auth login` in a terminal, then remembers the commit identity")
                    .font(.system(size: 10.5))
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
                    Text(account.login).font(.system(size: 12.5, weight: .semibold))
                    Text(email.isEmpty ? "no commit email set" : email)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isActive {
                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.ok)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.okBackground))
                } else {
                    Button("Switch") { store.setActive(account.login) }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
                }
            }

            VStack(spacing: 6) {
                LabeledField(label: "commit name", text: $name, placeholder: account.login)
                LabeledField(label: "commit email", text: $email, placeholder: "\(account.login)@users.noreply.github.com")
            }

            Text("Clones from this account commit with the identity above, regardless of your global ~/.gitconfig.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(isActive ? Theme.chipBorder : Theme.borderSoft))
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
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.panelBackground))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
        }
    }
}
