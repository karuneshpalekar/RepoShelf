import SwiftUI

struct CleanupView: View {
    @EnvironmentObject private var store: Store

    private var stale: [LocalRepo] { store.staleClones }

    private var reclaimBytes: Int64 {
        stale.reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                Text("Local copies you haven't opened in 3+ weeks. Everything here is pushed to GitHub — removing just frees the disk.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(stale, id: \.nameWithOwner) { clone in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(clone.nameWithOwner.split(separator: "/").last.map(String.init) ?? clone.nameWithOwner)
                                .font(.system(size: 12.5, weight: .semibold))
                            Text("last opened \(Formatting.relative(store.state.lastOpened[clone.nameWithOwner])) · \(Formatting.size(bytes: clone.sizeBytes))")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button {
                            store.remove(clone.nameWithOwner)
                        } label: {
                            Text("Remove")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.danger)
                                .padding(.horizontal, 11).padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.dangerBorder))
                    }
                    .padding(.horizontal, 11).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.borderSoft))
                }

                if stale.isEmpty {
                    EmptyHint(text: "Nothing stale — disk is tidy.")
                } else {
                    Button {
                        store.removeAllStale()
                    } label: {
                        Text("Remove all \(stale.count) · reclaim \(Formatting.size(bytes: reclaimBytes))")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.dangerBackground))
                    .padding(.top, 2)
                }
            }
            .padding(14)
        }
    }
}
