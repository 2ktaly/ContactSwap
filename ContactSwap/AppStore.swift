import Foundation
import Combine
import Contacts
import SwiftUI

/// Zentraler Zustand der App. Alle Views lesen und schreiben hierüber,
/// damit Backup-Liste und Adressbuch nie auseinanderlaufen.
@MainActor
final class AppStore: ObservableObject {
    @Published var permission: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    @Published var backups: [BackupMetadata] = []
    @Published var deviceContacts: [Contact] = []

    @Published var busyMessage: String?
    @Published var alert: AppAlert?
    @Published var verification: VerificationReport?

    var hasAccess: Bool { permission == .authorized || permission == .limited }

    // MARK: - Berechtigung

    func requestPermissionIfNeeded() async {
        if permission == .notDetermined {
            _ = await ContactService.shared.requestContactsAccess()
        }
        permission = CNContactStore.authorizationStatus(for: .contacts)
        if hasAccess {
            await reloadAll()
        }
    }

    func refreshPermission() {
        permission = CNContactStore.authorizationStatus(for: .contacts)
    }

    // MARK: - Laden

    func reloadAll() async {
        await reloadBackups()
        await reloadDeviceContacts()
    }

    func reloadBackups() async {
        do {
            backups = try await run { try BackupService.shared.listBackups() }
        } catch {
            alert = .error("Backups konnten nicht gelesen werden", error)
        }
    }

    func reloadDeviceContacts() async {
        guard hasAccess else { return }
        do {
            deviceContacts = try await run { try ContactService.shared.fetchAllContacts() }
        } catch {
            alert = .error("Kontakte konnten nicht gelesen werden", error)
        }
    }

    // MARK: - Backup

    func createBackup(named name: String) async {
        busyMessage = "Sichere Kontakte …"
        defer { busyMessage = nil }

        do {
            let contacts = try await run { try ContactService.shared.fetchAllContacts() }
            let backup = try await run { try BackupService.shared.createBackup(name: name, contacts: contacts) }
            deviceContacts = contacts
            await reloadBackups()

            // Direkt gegenprüfen: das Backup wird frisch von der Platte gelesen
            // und Feld für Feld mit dem Adressbuch verglichen.
            busyMessage = "Prüfe Backup …"
            let stored = try await run { try BackupService.shared.loadBackup(byID: backup.metadata.id).contacts }
            let notesSkipped = ContactService.shared.notesUnavailable
            let report = try await run {
                BackupVerifier.verify(backup: stored, against: contacts, notesSkipped: notesSkipped)
            }
            // Bei Abweichungen den Detailbericht zeigen, sonst genügt die Meldung.
            // Beides gleichzeitig würde SwiftUI verschlucken.
            if report.isComplete {
                alert = .info("Backup geprüft und vollständig", report.summary)
            } else {
                verification = report
            }
        } catch {
            alert = .error("Backup fehlgeschlagen", error)
        }
    }

    func deleteBackup(_ metadata: BackupMetadata) async {
        do {
            try await run { try BackupService.shared.deleteBackup(byID: metadata.id) }
            await reloadBackups()
        } catch {
            alert = .error("Backup konnte nicht gelöscht werden", error)
        }
    }

    func duplicateBackup(_ metadata: BackupMetadata) async {
        do {
            _ = try await run {
                try BackupService.shared.duplicateBackup(fromID: metadata.id, newName: metadata.name + " (Kopie)")
            }
            await reloadBackups()
            alert = .info("Zweitkopie angelegt", "Das Backup liegt jetzt doppelt vor.")
        } catch {
            alert = .error("Kopie fehlgeschlagen", error)
        }
    }

    /// Liest das Backup und das aktuelle Adressbuch neu ein und vergleicht beide
    /// Feld für Feld. Ergebnis landet in `verification`.
    func verifyBackup(_ metadata: BackupMetadata) async {
        busyMessage = "Vergleiche Backup mit Adressbuch …"
        defer { busyMessage = nil }

        do {
            let stored = try await run { try BackupService.shared.loadBackup(byID: metadata.id).contacts }
            let live = try await run { try ContactService.shared.fetchAllContacts() }
            let notesSkipped = ContactService.shared.notesUnavailable

            verification = try await run {
                BackupVerifier.verify(backup: stored, against: live, notesSkipped: notesSkipped)
            }
        } catch {
            alert = .error("Prüfung fehlgeschlagen", error)
        }
    }

    func exportBackup(_ metadata: BackupMetadata) async {
        busyMessage = "Exportiere …"
        defer { busyMessage = nil }

        do {
            let url = try await run { () -> URL in
                let backup = try BackupService.shared.loadBackup(byID: metadata.id)
                return try ExportService.shared.exportBackup(backup)
            }
            alert = .info(
                "Export abgelegt",
                "In der Dateien-App unter „Auf meinem iPhone → ContactSwap → \(url.lastPathComponent)“."
            )
        } catch {
            alert = .error("Export fehlgeschlagen", error)
        }
    }

    // MARK: - Swap

    /// Sichert zuerst das gesamte Adressbuch und löscht danach alle Kontakte
    /// bis auf die ausgewählten. Ohne erfolgreiches Backup wird nichts gelöscht.
    func swap(keeping keptIDs: Set<String>) async {
        busyMessage = "Sichere Kontakte …"

        do {
            let contacts = try await run { try ContactService.shared.fetchAllContacts() }
            guard !contacts.isEmpty else {
                busyMessage = nil
                alert = .info("Nichts zu tun", "Das Adressbuch ist bereits leer.")
                return
            }

            let name = "Vor Swap \(Self.stamp())"
            let backup = try await run { try BackupService.shared.createBackup(name: name, contacts: contacts) }

            busyMessage = "Entferne Kontakte …"
            let toDelete = contacts.map(\.id).filter { !keptIDs.contains($0) }
            let deleted = try await run { try ContactService.shared.deleteContacts(byIdentifiers: toDelete) }

            busyMessage = nil
            await reloadAll()
            alert = .info(
                "Adressbuch geleert",
                "\(deleted) Kontakte entfernt, \(keptIDs.count) behalten.\n\nGesichert als „\(backup.metadata.name)“ – über „Wiederherstellen“ kommt alles zurück."
            )
        } catch {
            busyMessage = nil
            alert = .error("Swap abgebrochen – es wurde nichts gelöscht", error)
        }
    }

    // MARK: - Restore

    func restore(_ metadata: BackupMetadata, removeCurrentFirst: Bool) async {
        busyMessage = "Stelle Kontakte wieder her …"

        do {
            let backup = try await run { try BackupService.shared.loadBackup(byID: metadata.id) }

            if removeCurrentFirst {
                busyMessage = "Räume Adressbuch auf …"
                let currentIDs = try await run { Array(try ContactService.shared.existingIdentifiers()) }
                _ = try await run { try ContactService.shared.deleteContacts(byIdentifiers: currentIDs) }
            }

            busyMessage = "Schreibe Kontakte zurück …"
            let written = try await run { try ContactService.shared.addContacts(backup.contacts) }

            busyMessage = nil
            await reloadAll()
            alert = .info("Wiederhergestellt", "\(written) Kontakte zurückgeschrieben.")
        } catch {
            busyMessage = nil
            alert = .error("Wiederherstellung fehlgeschlagen", error)
        }
    }

    // MARK: - Hilfen

    /// Führt blockierende Arbeit abseits des Main-Threads aus, damit die UI flüssig bleibt.
    private func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated) { try work() }.value
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f.string(from: Date())
    }
}

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func info(_ title: String, _ message: String) -> AppAlert {
        AppAlert(title: title, message: message)
    }

    static func error(_ title: String, _ error: Error) -> AppAlert {
        AppAlert(title: title, message: error.localizedDescription)
    }
}
