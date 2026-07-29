import SwiftUI

struct BackupView: View {
    @ObservedObject var store: AppStore
    @State private var backupName = ""
    @State private var pendingDeletion: BackupMetadata?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name, z. B. „Vor TikTok-Recherche“", text: $backupName)
                        .submitLabel(.done)

                    Button {
                        let name = trimmedName
                        backupName = ""
                        Task { await store.createBackup(named: name) }
                    } label: {
                        Label("Backup jetzt erstellen", systemImage: "square.and.arrow.down")
                    }
                    .disabled(trimmedName.isEmpty || store.busyMessage != nil)
                } header: {
                    Text("Neues Backup")
                } footer: {
                    Text("Sichert alle \(store.deviceContacts.count) Kontakte mit Namen, Nummern, E-Mails, Adressen, Geburtstagen und Fotos in Originalgröße.")
                }

                Section {
                    if store.backups.isEmpty {
                        Text("Noch kein Backup vorhanden.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.backups) { backup in
                            BackupRow(backup: backup)
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
                    }
                } header: {
                    Text("Vorhandene Backups (\(store.backups.count))")
                } footer: {
                    Text("Lange auf ein Backup tippen für Zweitkopie oder Export in die Dateien-App.")
                }
            }
            .navigationTitle("Sichern")
            .refreshable { await store.reloadAll() }
            .sheet(item: $store.verification) { report in
                VerificationView(report: report)
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

    private var trimmedName: String {
        backupName.trimmingCharacters(in: .whitespacesAndNewlines)
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
