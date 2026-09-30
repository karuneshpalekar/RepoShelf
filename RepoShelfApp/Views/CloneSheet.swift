import SwiftUI

struct CloneSheet: View {
    @EnvironmentObject private var store: Store
    let row: RepoRow
    let dismiss: () -> Void

    @State private var strategy: CloneStrategy = .blobless

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Download \(row.name)").font(.title3.weight(.semibold))
                Text("into \(store.destination(for: row.remote.nameWithOwner).path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
            }

            VStack(spacing: 6) {
                ForEach(CloneStrategy.allCases) { option in
                    let selected = strategy == option
                    Button {
                        strategy = option
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(selected ? Color.accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(option.title).fontWeight(.medium)
                                    Text("~\(Formatting.size(bytes: store.estimatedBytes(for: row, strategy: option)))")
                                        .foregroundStyle(.secondary)
                                }
                                Text(option.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selected ? Color.accentColor.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.accentColor : .clear))
                        .fullyClickable()
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: dismiss).keyboardShortcut(.cancelAction)
                Button("Download") {
                    store.clone(row, strategy: strategy)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 380)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
        .shadow(radius: 24, y: 8)
        .onAppear { strategy = store.state.cloneStrategies[row.remote.nameWithOwner] ?? .blobless }
    }
}
