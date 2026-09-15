/* Preview/Views/SourceGroupEditor.swift — Assign multiple clients to one preview slot. */
import ScreenCaptureKit
import SwiftUI

struct SourceGroupEditor: View {
    @ObservedObject var captureCoordinator: CaptureCoordinator
    @ObservedObject var previewManager: PreviewManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Source Group").font(.headline)
            Text("Choose the clients this preview can swap between. With Hide When Focused on, the preview shows an inactive member of the group.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(
                "Hide When Focused",
                isOn: Binding(
                    get: { captureCoordinator.effectiveHideWhenFocused },
                    set: { captureCoordinator.setHideWhenFocused($0) }
                )
            )
            .disabled(captureCoordinator.sources.count > 1)

            if captureCoordinator.sources.count > 1 {
                Text("Source groups with multiple clients always show the inactive member.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if previewManager.availableSources.isEmpty {
                Text("No source windows available. Refresh after granting Screen Recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(previewManager.availableSources, id: \.windowID) { source in
                        let identity = source.identity
                        let selected = identity.map { id in
                            captureCoordinator.sources.contains { $0.matchesClient(id) }
                        } ?? false
                        Button {
                            toggle(source)
                        } label: {
                            HStack {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.title ?? "Untitled")
                                    Text(source.owningApplication?.applicationName ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(identity == nil)
                    }
                }
                .frame(minHeight: 180)
            }

            HStack {
                Button("Refresh") {
                    Task { await previewManager.updateAvailableSources() }
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 360, height: 420)
        .task { await previewManager.updateAvailableSources() }
    }

    private func toggle(_ source: SCWindow) {
        guard let identity = source.identity else { return }
        var next = captureCoordinator.sources
        if let index = next.firstIndex(where: { $0.matchesClient(identity) }) {
            next.remove(at: index)
        } else {
            next.append(identity)
        }
        captureCoordinator.setSources(next)
    }
}
