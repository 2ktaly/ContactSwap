import Foundation
import CryptoKit

class BackupService {
    static let shared = BackupService()

    private let fileManager = FileManager.default
    private let photosFolderName = "photos"

    /// Backups liegen in Application Support – vom System nicht automatisch aufgeräumt
    /// und nicht für den Nutzer sichtbar. Der Export legt zusätzlich eine Kopie in
    /// "Dokumente" ab, die über die Dateien-App herausgezogen werden kann.
    private var backupsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Backups", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // Bewusst `let` statt `lazy var`: Die Methoden hier laufen über
    // Task.detached auf Hintergrund-Threads, und `lazy` ist nicht thread-sicher.
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Anlegen

    func createBackup(name: String, contacts: [Contact]) throws -> BackupFile {
        let key = try BackupCrypto.loadKey()
        let backupID = UUID().uuidString
        let backupDirectory = backupsDirectory.appendingPathComponent(backupID, isDirectory: true)
        let photosDirectory = backupDirectory.appendingPathComponent(photosFolderName, isDirectory: true)

        try fileManager.createDirectory(
            at: photosDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )

        // Fotos in Originalgröße als eigene Dateien ablegen, damit die JSON schlank bleibt.
        var storedContacts: [Contact] = []
        storedContacts.reserveCapacity(contacts.count)
        var totalPhotoSize = 0

        for var contact in contacts {
            if let imageData = contact.imageData, !imageData.isEmpty {
                let filename = "\(photosFolderName)/\(sanitizedFilename(for: contact.id)).img"
                let photoURL = backupDirectory.appendingPathComponent(filename)
                try write(imageData, to: photoURL, with: key)
                contact.photoPath = filename
                totalPhotoSize += imageData.count
            } else {
                contact.photoPath = nil
            }
            storedContacts.append(contact)
        }

        let metadata = BackupMetadata(
            id: backupID,
            name: name,
            timestamp: Date(),
            contactCount: storedContacts.count,
            photoCount: storedContacts.filter { $0.photoPath != nil }.count,
            totalPhotosSizeBytes: totalPhotoSize,
            appVersion: Bundle.main.shortVersion
        )

        try write(encoder.encode(storedContacts),
                  to: backupDirectory.appendingPathComponent("contacts.json"), with: key)
        try write(encoder.encode(metadata),
                  to: backupDirectory.appendingPathComponent("metadata.json"), with: key)

        return BackupFile(metadata: metadata, contacts: storedContacts, backupDirectoryURL: backupDirectory)
    }

    // MARK: - Lesen

    func listBackups() throws -> [BackupMetadata] {
        let entries = try fileManager.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        guard !entries.isEmpty else { return [] }

        let key = try BackupCrypto.loadKey()

        var backups: [BackupMetadata] = []
        for url in entries {
            let metadataFile = url.appendingPathComponent("metadata.json")
            guard fileManager.fileExists(atPath: metadataFile.path) else { continue }
            guard let data = try? read(metadataFile, with: key),
                  let metadata = try? decoder.decode(BackupMetadata.self, from: data) else { continue }
            backups.append(metadata)
        }

        return backups.sorted { $0.timestamp > $1.timestamp }
    }

    /// Lädt ein Backup inklusive der Fotos zurück in den Speicher.
    func loadBackup(byID id: String) throws -> BackupFile {
        let key = try BackupCrypto.loadKey()
        let backupDirectory = backupsDirectory.appendingPathComponent(id, isDirectory: true)

        let metadata = try decoder.decode(
            BackupMetadata.self,
            from: read(backupDirectory.appendingPathComponent("metadata.json"), with: key)
        )
        var contacts = try decoder.decode(
            [Contact].self,
            from: read(backupDirectory.appendingPathComponent("contacts.json"), with: key)
        )

        for index in contacts.indices {
            guard let photoPath = contacts[index].photoPath else { continue }
            let photoURL = backupDirectory.appendingPathComponent(photoPath)
            contacts[index].imageData = try? read(photoURL, with: key)
        }

        return BackupFile(metadata: metadata, contacts: contacts, backupDirectoryURL: backupDirectory)
    }

    // MARK: - Verwalten

    func deleteBackup(byID id: String) throws {
        let backupDirectory = backupsDirectory.appendingPathComponent(id, isDirectory: true)
        guard fileManager.fileExists(atPath: backupDirectory.path) else { return }
        try fileManager.removeItem(at: backupDirectory)
    }

    /// Legt eine zweite, unabhängige Kopie des Backups an (doppelt gesichert).
    @discardableResult
    func duplicateBackup(fromID sourceID: String, newName: String) throws -> BackupMetadata {
        let key = try BackupCrypto.loadKey()
        let sourceDirectory = backupsDirectory.appendingPathComponent(sourceID, isDirectory: true)
        let newID = UUID().uuidString
        let newDirectory = backupsDirectory.appendingPathComponent(newID, isDirectory: true)

        try fileManager.copyItem(at: sourceDirectory, to: newDirectory)

        let original = try decoder.decode(
            BackupMetadata.self,
            from: read(newDirectory.appendingPathComponent("metadata.json"), with: key)
        )

        let copy = BackupMetadata(
            id: newID,
            name: newName,
            timestamp: Date(),
            contactCount: original.contactCount,
            photoCount: original.photoCount,
            totalPhotosSizeBytes: original.totalPhotosSizeBytes,
            appVersion: original.appVersion
        )

        try write(encoder.encode(copy),
                  to: newDirectory.appendingPathComponent("metadata.json"), with: key)

        return copy
    }

    // MARK: - Verschlüsselt lesen und schreiben

    /// Schreibt verschlüsselt und mit vollem Dateischutz: Selbst wer die Datei
    /// aus dem Container zieht, bekommt ohne den Schlüssel aus dem Keychain
    /// dieses Geräts nichts zu sehen.
    private func write(_ data: Data, to url: URL, with key: SymmetricKey) throws {
        try BackupCrypto.seal(data, with: key)
            .write(to: url, options: [.atomic, .completeFileProtection])
    }

    private func read(_ url: URL, with key: SymmetricKey) throws -> Data {
        try BackupCrypto.open(Data(contentsOf: url), with: key)
    }

    // MARK: - Hilfen

    private func sanitizedFilename(for identifier: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(identifier.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }
}

extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
