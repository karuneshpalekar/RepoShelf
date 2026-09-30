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
                Text("Add a repo").font(.title3.weight(.semibold))
                Text("Paste a GitHub URL or owner/name — for repos outside your own list (orgs, forks, collaborators).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("github.com/acme/dashboard  or  acme/dashboard", text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                .onSubmit(add)

            HStack(spacing: 7) {
                Text("clone with").foregroundStyle(.secondary)
                Text(store.activeLogin).fontWeight(.semibold)
                Text("· blobless").foregroundStyle(.secondary)
            }
            .font(.callout)

            if let localError {
                Text(localError).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", action: dismiss).keyboardShortcut(.cancelAction)
                Button(action: add) {
                    HStack(spacing: 5) {
                        if working { ProgressView().controlSize(.mini) }
                        Text("Add & clone")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(working)
            }
        }
        .padding(16)
        .frame(width: 380)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
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
