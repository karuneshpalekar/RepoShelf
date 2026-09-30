import SwiftUI

struct CleanupView: View {
    @EnvironmentObject private var store: Store

    private var stale: [LocalRepo] { store.staleClones }

    private var reclaimBytes: Int64 {
        stale.reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        if stale.isEmpty {
            ContentUnavailableView(
                "Disk is tidy", systemImage: "checkmark.seal",
                description: Text("Nothing here has sat untouched for 3+ weeks.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Local copies you haven't opened in 3+ weeks. Everything here is pushed to GitHub — removing just frees the disk, and the repo stays in the Repos tab with a Download button to pull it back anytime.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(stale, id: \.nameWithOwner) { clone in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(clone.nameWithOwner.split(separator: "/").last.map(String.init) ?? clone.nameWithOwner)
                                    .fontWeight(.medium)
                                Text("last opened \(Formatting.relative(store.state.lastOpened[clone.nameWithOwner])) · \(Formatting.size(bytes: clone.sizeBytes))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Button("Remove") { store.remove(clone.nameWithOwner) }
                                .buttonStyle(.bordered)
                                .tint(.red)
                        }
                        .padding(.horizontal, 11).padding(.vertical, 10)
                        .cardStyle(radius: 9)
                    }

                    Button {
                        store.removeAllStale()
                    } label: {
                        Text("Remove all \(stale.count) · reclaim \(Formatting.size(bytes: reclaimBytes))")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .padding(.top, 2)
                }
                .padding(14)
            }
        }
    }
}
