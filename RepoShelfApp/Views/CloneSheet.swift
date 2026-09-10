import SwiftUI

struct CloneSheet: View {
    @EnvironmentObject private var store: Store
    let row: RepoRow
    let dismiss: () -> Void

    @State private var strategy: CloneStrategy = .blobless

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Download \(row.name)").font(.system(size: 13.5, weight: .bold))
                Text("into \(store.destination(for: row.remote.nameWithOwner).path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
            }

            VStack(spacing: 6) {
                ForEach(CloneStrategy.allCases) { option in
                    Button {
                        strategy = option
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: strategy == option ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(strategy == option ? Theme.accent : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(option.title).font(.system(size: 12, weight: .semibold))
                                    Text("~\(Formatting.size(bytes: store.estimatedBytes(for: row, strategy: option)))")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Text(option.subtitle)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(strategy == option ? Theme.chipBackground : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(strategy == option ? Theme.accent : Theme.border))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.hitFull)
                }
            }

            HStack {
                Spacer()
                SheetButton(title: "Cancel", action: dismiss)
                SheetButton(title: "Download", kind: .primary) {
                    store.clone(row, strategy: strategy)
                    dismiss()
                }
            }
        }
        .padding(16)
        .frame(width: 380)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .shadow(radius: 24, y: 8)
        .onAppear { strategy = store.state.cloneStrategies[row.remote.nameWithOwner] ?? .blobless }
    }
}
