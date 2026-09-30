import SwiftUI
import AppKit

struct SettingsPopover: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scan folders").font(.headline)
            Text("RepoShelf looks in these folders for clones you already have and maps each to its GitHub repo by its origin remote.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(store.state.scanRootPaths.enumerated()), id: \.element) { index, path in
                    if index > 0 { Divider() }
                    HStack(spacing: 6) {
                        Image(systemName: "folder").foregroundStyle(.secondary)
                        Text(path).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 0)
                        Button {
                            store.removeScanRoot(path)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tertiary)
                        .help("Remove folder")
                    }
                    .font(.callout)
                    .padding(.vertical, 5)
                }
            }

            HStack {
                Button {
                    chooseFolder()
                } label: {
                    Label("Add folder…", systemImage: "plus")
                }
                .buttonStyle(.link)

                Spacer()

                Button {
                    store.refreshCurrent()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.link)
            }
            .font(.callout)

            Divider()

            HStack(spacing: 6) {
                Text("New clones go to").foregroundStyle(.secondary)
                Text(store.state.workspaceRootPath.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .fontWeight(.medium)
                    .lineLimit(1).truncationMode(.middle)
            }
            .font(.caption)
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
