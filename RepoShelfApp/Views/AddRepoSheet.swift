import SwiftUI

struct AddRepoSheet: View {
    @EnvironmentObject private var store: Store
    let dismiss: () -> Void

    @State private var text = ""
    @State private var working = false
    @State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Add a repo").font(.system(size: 13.5, weight: .bold))
                Text("Paste a GitHub URL or owner/name — for repos outside your own list (orgs, forks, collaborators).")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("github.com/acme/dashboard  or  acme/dashboard", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.panelBackground))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                .onSubmit(add)

            HStack(spacing: 7) {
                Text("clone with").foregroundStyle(.secondary)
                Text(store.activeLogin).fontWeight(.semibold)
                Text("· blobless").foregroundStyle(.secondary)
            }
            .font(.system(size: 11))

            if let localError {
                Text(localError).font(.system(size: 10.5)).foregroundStyle(Theme.danger)
            }

            HStack {
                Spacer()
                SheetButton(title: "Cancel", action: dismiss)
                Button(action: add) {
                    HStack(spacing: 5) {
                        if working { ProgressView().controlSize(.mini) }
                        Text("Add & clone").font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Theme.accent))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.hitFull)
                .disabled(working)
                .opacity(working ? 0.6 : 1)
            }
        }
        .padding(16)
        .frame(width: 380)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .shadow(radius: 24, y: 8)
    }

    private func add() {
        guard !working else { return }
        localError = nil
        working = true
        Task {
            let ok = await store.addRepo(from: text)
            working = false
            if ok {
                if let slug = GitHub.parseSlug(text),
                   let row = store.rows.first(where: { $0.id == slug }) {
                    store.clone(row, strategy: .blobless)
                }
                dismiss()
            } else {
                localError = store.errorMessage
            }
        }
    }
}
