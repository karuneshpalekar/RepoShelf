import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(store.state.activity) { event in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: icon(for: event.kind))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(color(for: event.kind))
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6).fill(background(for: event.kind)))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(headline(for: event))
                                .font(.system(size: 11.5))
                            Text("\(Formatting.relative(event.date)) · \(event.detail)")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 2)
                }

                if store.state.activity.isEmpty {
                    EmptyHint(text: "No activity yet.")
                }
            }
            .padding(14)
        }
    }

    private func headline(for event: ActivityEvent) -> String {
        switch event.kind {
        case .clone: return "Cloned \(event.subject)"
        case .remove: return "Removed local copy of \(event.subject)"
        case .switchAccount: return "Switched to \(event.subject)"
        case .addAccount: return "Added account \(event.subject)"
        }
    }

    private func icon(for kind: ActivityEvent.Kind) -> String {
        switch kind {
        case .clone: return "arrow.down.to.line"
        case .remove: return "xmark"
        case .switchAccount: return "arrow.left.arrow.right"
        case .addAccount: return "plus"
        }
    }

    private func color(for kind: ActivityEvent.Kind) -> Color {
        switch kind {
        case .clone: return Theme.ok
        case .remove: return Theme.danger
        case .switchAccount, .addAccount: return Theme.accent
        }
    }

    private func background(for kind: ActivityEvent.Kind) -> Color {
        switch kind {
        case .clone: return Theme.okBackground
        case .remove: return Theme.dangerBackground
        case .switchAccount, .addAccount: return Theme.chipBackground
        }
    }
}
