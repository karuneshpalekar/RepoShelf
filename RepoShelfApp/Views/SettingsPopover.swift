import SwiftUI
import AppKit

struct SettingsPopover: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scan folders")
                .font(.system(size: 12, weight: .bold))
            Text("RepoShelf looks in these folders for clones you already have and maps each to its GitHub repo by its origin remote.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 4) {
                ForEach(store.state.scanRootPaths, id: \.self) { path in
                    HStack(spacing: 6) {
                        Image(systemName: "folder").font(.system(size: 10)).foregroundStyle(.secondary)
                        Text(path).font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 0)
                        Button {
                            store.removeScanRoot(path)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.hitFull)
                        .help("Remove folder")
                    }
                    .padding(.leading, 8).padding(.trailing, 3).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surfaceSecondary))
                }
            }

            HStack {
                Button {
                    chooseFolder()
                } label: {
                    Label("Add folder…", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.vertical, 4).padding(.trailing, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.hitFull)

                Spacer()

                Button {
                    store.refreshCurrent()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.vertical, 4).padding(.leading, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.hitFull)
            }

            Divider().overlay(Theme.borderSoft)

            HStack(spacing: 6) {
                Text("New clones go to")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text(store.state.workspaceRootPath.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1).truncationMode(.middle)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK, let url = panel.url {
            store.addScanRoot(url)
        }
    }
}
