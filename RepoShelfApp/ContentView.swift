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

@MainActor
struct ContentView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var panelState: PanelState
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue

    @State private var query = ""
    @State private var clonedOnly = false
    @State private var showSettings = false

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
                    Divider()
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .modifier(FadeIn())
                        .id(panelState.tab)
                    Divider()
                    footer
                }
                overlays
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .preferredColorScheme(appearance.colorScheme)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("RepoShelf").font(.headline)
                }
                Text("Pull projects from GitHub only when you need them")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            accountSwitcher

            AppearanceToggle()

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help("Scan folders & settings")
            .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                SettingsPopover().environmentObject(store)
            }

            Button {
                withAnimation(Motion.swap) { panelState.isCollapsed = true }
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .buttonStyle(.borderless)
            .help("Collapse to pill")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(DragHandle())
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
            Button("Add account…") { panelState.activeSheet = .addAccount }
        } label: {
            Label(store.activeLogin.isEmpty ? "No account" : store.activeLogin, systemImage: "person.crop.circle.fill")
                .foregroundStyle(store.activeLogin.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(AccountPalette.color(store.activeLogin)))
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: 140)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: Tabs

    private var tabBar: some View {
        Picker("", selection: $panelState.tab.animation(Motion.screen)) {
            ForEach(ShelfTab.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch panelState.tab {
        case .repos:
            ReposView(
                query: $query,
                clonedOnly: $clonedOnly,
                onClone: { row in panelState.activeSheet = .clone(row.id) },
                onAddRepo: { panelState.activeSheet = .addRepo }
            )
        case .publish:
            PublishView(onPublish: { panelState.activeSheet = .publish($0.path) })
        case .cleanup:
            CleanupView()
        case .accounts:
            AccountsView(onAddAccount: { panelState.activeSheet = .addAccount })
        case .activity:
            ActivityView()
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            WorkspaceBar(used: store.workspaceBytes, free: store.freeDiskBytes)
                .frame(height: 6)

            HStack(spacing: 4) {
                if store.isScanning || store.isLoadingRepos {
                    ProgressView().controlSize(.mini)
                }
                Text("workspace ")
                    .foregroundStyle(.secondary)
                + Text(Formatting.size(bytes: store.workspaceBytes)).fontWeight(.semibold).monospacedDigit()
                + Text(" · \(Formatting.size(bytes: store.freeDiskBytes)) free").foregroundStyle(.secondary)
            }
            .font(.caption)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.bar)
    }

    // MARK: Overlays (sheets rendered manually — the panel is borderless)

    @ViewBuilder
    private var overlays: some View {
        if let activeSheet = panelState.activeSheet {
            Color.black.opacity(0.28).ignoresSafeArea()
                .onTapGesture { panelState.activeSheet = nil }

            Group {
                switch activeSheet {
                case .clone(let slug):
                    if let row = store.rows.first(where: { $0.id == slug }) {
                        CloneSheet(row: row) { panelState.activeSheet = nil }
                    }
                case .addRepo:
                    AddRepoSheet { panelState.activeSheet = nil }
                case .addAccount:
                    AddAccountSheet { panelState.activeSheet = nil }
                case .publish(let path):
                    PublishSheet(folderPath: path) { panelState.activeSheet = nil }
                }
            }
            .padding(22)
            .transition(.opacity)
            .animation(Motion.swap, value: panelState.activeSheet)
        }
    }
}

// MARK: - Shared bits

/// Fades a screen in when it appears — the same technique DevSweep uses in
/// place of a removal transition (which fights NavigationSplitView there;
/// harmless here, but keeping one Motion vocabulary app-to-app).
struct FadeIn: ViewModifier {
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(Motion.screen) { shown = true } }
    }
}

struct AccountAvatar: View {
    let login: String
    var size: CGFloat = 18

    var body: some View {
        Circle()
            .fill(AccountPalette.color(login))
            .frame(width: size, height: size)
            .overlay(
                Text(login.isEmpty ? "?" : String(login.prefix(1)).uppercased())
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}

/// Free / workspace / other-used bar, same shape as DevSweep's DiskBar.
struct WorkspaceBar: View {
    let used: Int64
    let free: Int64
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let total = max(Double(used) + Double(free), 1)
            let otherFrac = min(0.62, 1 - Double(used) / total)
            let usedFrac = min(0.30, Double(used) / total + 0.02)
            HStack(spacing: 0) {
                Rectangle().fill(.secondary.opacity(0.6)).frame(width: geo.size.width * otherFrac)
                Rectangle().fill(Color.accentColor).frame(width: geo.size.width * usedFrac)
                Rectangle().fill(.quaternary)
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("\(Formatting.size(bytes: used)) workspace, \(Formatting.size(bytes: free)) free")
    }
}

struct CompactPillView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var panelState: PanelState

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.accentColor).frame(width: 34, height: 34)
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.localRepos.count) on disk").fontWeight(.semibold)
                Text("\(Formatting.size(bytes: store.freeDiskBytes)) free")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        // Exact size, not maxWidth/maxHeight: .infinity: when NSHostingView
        // queries this view's ideal size with no proposed size to expand
        // into (which it does for window auto-sizing), "infinity" resolves
        // to the content's own natural size instead of the window's, and
        // the window silently resizes to match. A concrete frame matching
        // FloatingPanel.collapsedSize removes that ambiguity.
        .frame(width: FloatingPanel.collapsedSize.width, height: FloatingPanel.collapsedSize.height)
        .background(DragHandle())
        .background(.background)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
        .fullyClickable()
        .onTapGesture { withAnimation(Motion.swap) { panelState.isCollapsed = false } }
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
