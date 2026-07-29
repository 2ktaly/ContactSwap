import Foundation

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

    private lazy var encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Anlegen

    func createBackup(name: String, contacts: [Contact]) throws -> BackupFile {
        let backupID = UUID().uuidString
        let backupDirectory = backupsDirectory.appendingPathComponent(backupID, isDirectory: true)
        let photosDirectory = backupDirectory.appendingPathComponent(photosFolderName, isDirectory: true)

        try fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)

        // Fotos in Originalgröße als eigene Dateien ablegen, damit die JSON schlank bleibt.
        var storedContacts: [Contact] = []
        storedContacts.reserveCapacity(contacts.count)
        var totalPhotoSize = 0

        for var contact in contacts {
            if let imageData = contact.imageData, !imageData.isEmpty {
                let filename = "\(photosFolderName)/\(sanitizedFilename(for: contact.id)).img"
                let photoURL = backupDirectory.appendingPathComponent(filename)
                try imageData.write(to: photoURL, options: .atomic)
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

        try encoder.encode(storedContacts)
            .write(to: backupDirectory.appendingPathComponent("contacts.json"), options: .atomic)
        try encoder.encode(metadata)
            .write(to: backupDirectory.appendingPathComponent("metadata.json"), options: .atomic)

        return BackupFile(metadata: metadata, contacts: storedContacts, backupDirectoryURL: backupDirectory)
    }

    // MARK: - Lesen

    func listBackups() throws -> [BackupMetadata] {
        let entries = try fileManager.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var backups: [BackupMetadata] = []
        for url in entries {
            let metadataFile = url.appendingPathComponent("metadata.json")
            guard fileManager.fileExists(atPath: metadataFile.path) else { continue }
            guard let data = try? Data(contentsOf: metadataFile),
                  let metadata = try? decoder.decode(BackupMetadata.self, from: data) else { continue }
            backups.append(metadata)
        }

        return backups.sorted { $0.timestamp > $1.timestamp }
    }

    /// Lädt ein Backup inklusive der Fotos zurück in den Speicher.
    func loadBackup(byID id: String) throws -> BackupFile {
        let backupDirectory = backupsDirectory.appendingPathComponent(id, isDirectory: true)

        let metadata = try decoder.decode(
            BackupMetadata.self,
            from: Data(contentsOf: backupDirectory.appendingPathComponent("metadata.json"))
        )
        var contacts = try decoder.decode(
            [Contact].self,
            from: Data(contentsOf: backupDirectory.appendingPathComponent("contacts.json"))
        )

        for index in contacts.indices {
            guard let photoPath = contacts[index].photoPath else { continue }
            let photoURL = backupDirectory.appendingPathComponent(photoPath)
            contacts[index].imageData = try? Data(contentsOf: photoURL)
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
        let sourceDirectory = backupsDirectory.appendingPathComponent(sourceID, isDirectory: true)
        let newID = UUID().uuidString
        let newDirectory = backupsDirectory.appendingPathComponent(newID, isDirectory: true)

        try fileManager.copyItem(at: sourceDirectory, to: newDirectory)

        let original = try decoder.decode(
            BackupMetadata.self,
            from: Data(contentsOf: newDirectory.appendingPathComponent("metadata.json"))
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

        try encoder.encode(copy)
            .write(to: newDirectory.appendingPathComponent("metadata.json"), options: .atomic)

        return copy
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
