import SwiftUI

struct RestoreView: View {
    @ObservedObject var store: AppStore

    @State private var selected: BackupMetadata?
    @State private var pendingDeletion: BackupMetadata?
    @State private var replaceExisting = true

    var body: some View {
        NavigationStack {
            Group {
                if store.backups.isEmpty {
                    ContentUnavailableView(
                        "Kein Backup vorhanden",
                        systemImage: "tray",
                        description: Text("Sobald du unter „Swap“ das Adressbuch leerst, legt die App automatisch ein Backup an – es erscheint dann hier.")
                    )
                } else {
                    backupList
                }
            }
            .navigationTitle("Zurück")
            .refreshable { await store.reloadBackups() }
            .sheet(item: $store.verification) { report in
                VerificationView(report: report)
            }
            .confirmationDialog(
                "„\(selected?.name ?? "")“ wiederherstellen?",
                isPresented: Binding(
                    get: { selected != nil },
                    set: { if !$0 { selected = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Wiederherstellen") {
                    if let backup = selected {
                        let replace = replaceExisting
                        Task { await store.restore(backup, removeCurrentFirst: replace) }
                    }
                    selected = nil
                }
                Button("Abbrechen", role: .cancel) { selected = nil }
            } message: {
                if let backup = selected {
                    Text("\(backup.contactCount) Kontakte und \(backup.photoCount) Fotos werden zurückgeschrieben.")
                }
            }
            .confirmationDialog(
                "Backup „\(pendingDeletion?.name ?? "")“ löschen?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Endgültig löschen", role: .destructive) {
                    if let backup = pendingDeletion {
                        Task { await store.deleteBackup(backup) }
                    }
                    pendingDeletion = nil
                }
                Button("Abbrechen", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("Die gesicherten Kontakte dieses Backups gehen verloren.")
            }
        }
    }

    private var backupList: some View {
        List {
            Section {
                Toggle("Aktuelle Kontakte vorher entfernen", isOn: $replaceExisting)
            } footer: {
                Text(replaceExisting
                     ? "Das Adressbuch wird geleert und exakt auf den Stand des Backups gebracht. Empfohlen nach einem Swap."
                     : "Die Kontakte aus dem Backup werden zusätzlich eingefügt. Kann zu Dubletten führen.")
            }

            Section {
                ForEach(store.backups) { backup in
                    Button {
                        selected = backup
                    } label: {
                        BackupRow(backup: backup)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDeletion = backup
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            Task { await store.verifyBackup(backup) }
                        } label: {
                            Label("Vollständigkeit prüfen", systemImage: "checkmark.seal")
                        }
                        Button {
                            Task { await store.duplicateBackup(backup) }
                        } label: {
                            Label("Zweitkopie anlegen", systemImage: "doc.on.doc")
                        }
                        Button {
                            Task { await store.exportBackup(backup) }
                        } label: {
                            Label("In Dateien exportieren", systemImage: "folder")
                        }
                        Button(role: .destructive) {
                            pendingDeletion = backup
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Backup auswählen (\(store.backups.count))")
            } footer: {
                Text("Lange auf ein Backup tippen für Prüfung, Zweitkopie oder Export in die Dateien-App. Wischen zum Löschen.")
            }
        }
    }
}

struct BackupRow: View {
    let backup: BackupMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(backup.name)
                .font(.headline)

            HStack(spacing: 12) {
                Label("\(backup.contactCount)", systemImage: "person.2.fill")
                Label("\(backup.photoCount)", systemImage: "photo.fill")
                if backup.totalPhotosSizeBytes > 0 {
                    Text(backup.formattedSize)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(backup.formattedDate)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
