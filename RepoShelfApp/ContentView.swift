import SwiftUI

enum ShelfTab: String, CaseIterable, Identifiable {
    case repos = "Repos"
    case publish = "Publish"
    case cleanup = "Cleanup"
    case accounts = "Accounts"
    case activity = "Activity"
    var id: String { rawValue }
}

enum ActiveSheet: Identifiable, Equatable {
    case clone(String)
    case addRepo
    case addAccount
    case publish(String)

    var id: String {
        switch self {
        case .clone(let slug): return "clone:\(slug)"
        case .addRepo: return "addRepo"
        case .addAccount: return "addAccount"
        case .publish(let path): return "publish:\(path)"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var panelState: PanelState
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue

    @State private var tab: ShelfTab = .repos
    @State private var query = ""
    @State private var clonedOnly = false
    @State private var showAccountMenu = false
    @State private var showSettings = false
    @State private var activeSheet: ActiveSheet?

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        ZStack {
            if panelState.isCollapsed {
                CompactPillView()
            } else {
                VStack(spacing: 0) {
                    header
                    tabBar
                    Divider().overlay(Theme.borderSoft)
                    content
                    Divider().overlay(Theme.borderSoft)
                    footer
                }
                overlays
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.panelBackground)
        .tint(Theme.accent)
        .preferredColorScheme(appearance.colorScheme)
        .font(.system(size: 12))
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.accent)
                    Text("RepoShelf")
                        .font(.system(size: 15, weight: .bold))
                }
                Text("Pull projects from GitHub only when you need them")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            accountSwitcher

            Button {
                cycleAppearance()
            } label: {
                Image(systemName: appearance.icon)
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.border))
            .help("Appearance: \(appearance.label)")

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.border))
            .help("Scan folders & settings")
            .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                SettingsPopover().environmentObject(store)
            }

            Button {
                panelState.isCollapsed = true
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 11))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.border))
            .help("Collapse to pill")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(DragHandle())
        .overlay(alignment: .bottom) { Divider().overlay(Theme.borderSoft) }
    }

    private var accountSwitcher: some View {
        Menu {
            ForEach(store.accounts) { account in
                Button {
                    store.setActive(account.login)
                } label: {
                    Label(account.login, systemImage: account.login == store.activeLogin ? "checkmark" : "")
                }
            }
            Divider()
            Button("Add account…") { activeSheet = .addAccount }
        } label: {
            HStack(spacing: 6) {
                AccountAvatar(login: store.activeLogin, size: 16)
                Text(store.activeLogin.isEmpty ? "No account" : store.activeLogin)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: 128)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.border))
    }

    private func cycleAppearance() {
        let all = AppearanceMode.allCases
        let idx = all.firstIndex(of: appearance) ?? 0
        appearanceRaw = all[(idx + 1) % all.count].rawValue
    }

    // MARK: Tabs

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(ShelfTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tab == item ? Color.primary : Color.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7)
                                .fill(tab == item ? Theme.panelBackground : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .repos:
            ReposView(
                query: $query,
                clonedOnly: $clonedOnly,
                onClone: { row in activeSheet = .clone(row.id) },
                onAddRepo: { activeSheet = .addRepo }
            )
        case .publish:
            PublishView(onPublish: { activeSheet = .publish($0.path) })
        case .cleanup:
            CleanupView()
        case .accounts:
            AccountsView(onAddAccount: { activeSheet = .addAccount })
        case .activity:
            ActivityView()
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            GeometryReader { geo in
                let total = max(store.workspaceBytes + store.freeDiskBytes, 1)
                let usedFrac = 0.62
                let wsFrac = min(0.30, Double(store.workspaceBytes) / Double(total) + 0.02)
                HStack(spacing: 0) {
                    Rectangle().fill(Theme.border).frame(width: geo.size.width * usedFrac)
                    Rectangle().fill(Theme.accent).frame(width: geo.size.width * wsFrac)
                    Rectangle().fill(Theme.borderSoft)
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)

            HStack(spacing: 4) {
                if store.isScanning || store.isLoadingRepos {
                    ProgressView().controlSize(.mini)
                }
                Text("workspace ")
                    .foregroundStyle(.secondary)
                + Text(Formatting.size(bytes: store.workspaceBytes)).fontWeight(.bold)
                + Text(" · \(Formatting.size(bytes: store.freeDiskBytes)) free").foregroundStyle(.secondary)
            }
            .font(.system(size: 10.5))
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.surfaceSecondary)
    }

    // MARK: Overlays (sheets rendered manually — the panel is borderless)

    @ViewBuilder
    private var overlays: some View {
        if let activeSheet {
            Color.black.opacity(0.28).ignoresSafeArea()
                .onTapGesture { self.activeSheet = nil }

            Group {
                switch activeSheet {
                case .clone(let slug):
                    if let row = store.rows.first(where: { $0.id == slug }) {
                        CloneSheet(row: row) { self.activeSheet = nil }
                    }
                case .addRepo:
                    AddRepoSheet { self.activeSheet = nil }
                case .addAccount:
                    AddAccountSheet { self.activeSheet = nil }
                case .publish(let path):
                    PublishSheet(folderPath: path) { self.activeSheet = nil }
                }
            }
            .padding(22)
            .transition(.opacity)
        }
    }
}

// MARK: - Shared bits

struct AccountAvatar: View {
    let login: String
    var size: CGFloat = 18

    var body: some View {
        Circle()
            .fill(Theme.accountColor(login))
            .frame(width: size, height: size)
            .overlay(
                Text(login.isEmpty ? "?" : String(login.prefix(1)).uppercased())
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}

struct CompactPillView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var panelState: PanelState

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.accent.gradient).frame(width: 34, height: 34)
                Image(systemName: "tray.full.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.localRepos.count) on disk")
                    .font(.system(size: 12, weight: .bold))
                Text("\(Formatting.size(bytes: store.freeDiskBytes)) free")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DragHandle())
        .contentShape(Rectangle())
        .onTapGesture { panelState.isCollapsed = false }
    }
}

/// A small pill button used for row actions.
struct IconActionButton: View {
    let systemName: String
    var tint: Color = .secondary
    var borderColor: Color = Theme.border
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor))
    }
}

struct EmptyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }
}
