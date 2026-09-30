import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        if store.state.activity.isEmpty {
            ContentUnavailableView(
                "No activity yet", systemImage: "clock",
                description: Text("Clones, removals and account switches show up here.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(store.state.activity) { event in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: icon(for: event.kind))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tag(for: event.kind).color)
                                .frame(width: 22, height: 22)
                                .background(tag(for: event.kind).color.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(headline(for: event)).font(.callout)
                                Text("\(Formatting.relative(event.date)) · \(event.detail)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 2)
                    }
                }
                .padding(14)
            }
        }
    }

    private func headline(for event: ActivityEvent) -> String {
        switch event.kind {
        case .clone: return "Cloned \(event.subject)"
        case .remove: return "Removed local copy of \(event.subject)"
        case .switchAccount: return "Switched to \(event.subject)"
        case .addAccount: return "Added account \(event.subject)"
        case .publish: return "Published \(event.subject)"
        }
    }

    private func icon(for kind: ActivityEvent.Kind) -> String {
        switch kind {
        case .clone: return "arrow.down.to.line"
        case .remove: return "xmark"
        case .switchAccount: return "arrow.left.arrow.right"
        case .addAccount: return "plus"
        case .publish: return "arrow.up.to.line"
        }
    }

    private func tag(for kind: ActivityEvent.Kind) -> Tag {
        switch kind {
        case .clone: return .onDisk
        case .remove: return .destructive
        case .switchAccount, .addAccount, .publish: return .info
        }
    }
}
