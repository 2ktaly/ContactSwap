import Foundation

class ExportService {
    static let shared = ExportService()

    private let fileManager = FileManager.default

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    /// Der Dokumente-Ordner der App. Über die Dateien-App sichtbar, sobald
    /// UIFileSharingEnabled gesetzt ist – von dort lässt sich der Export auf
    /// iCloud, NAS oder Rechner kopieren.
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Legt eine vollständige Kopie des Backups (inkl. Fotos) in "Dokumente" ab.
    ///
    /// Bewusst **unverschlüsselt**: Der Export existiert, um die Kontakte vom
    /// Gerät herunterzubekommen. Die internen Backups sind an den Schlüssel im
    /// Keychain dieses iPhones gebunden – ein verschlüsselter Export wäre genau
    /// dann wertlos, wenn man ihn braucht, nämlich wenn das Gerät weg ist.
    @discardableResult
    func exportBackup(_ backup: BackupFile) throws -> URL {
        let stamp = Self.filenameFormatter.string(from: backup.metadata.timestamp)
        let folderName = "ContactSwap \(sanitized(backup.metadata.name)) \(stamp)"
        let destination = documentsDirectory.appendingPathComponent(folderName, isDirectory: true)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        let photosDirectory = destination.appendingPathComponent("photos", isDirectory: true)
        try fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)

        for contact in backup.contacts {
            guard let photoPath = contact.photoPath, let imageData = contact.imageData else { continue }
            try imageData.write(to: destination.appendingPathComponent(photoPath), options: .atomic)
        }

        try encoder.encode(backup.contacts)
            .write(to: destination.appendingPathComponent("contacts.json"), options: .atomic)
        try encoder.encode(backup.metadata)
            .write(to: destination.appendingPathComponent("metadata.json"), options: .atomic)
        try Self.warningText.data(using: .utf8)?
            .write(to: destination.appendingPathComponent("LIESMICH.txt"), options: .atomic)

        return destination
    }

    private static let warningText = """
    ContactSwap – exportiertes Backup

    Dieser Ordner ist UNVERSCHLÜSSELT und enthält vollständige Kontaktdaten
    inklusive Namen, Nummern, Adressen, Geburtstagen und Fotos.

    Innerhalb der App liegen Backups verschlüsselt; dieser Export ist es nicht,
    damit er sich auch ohne dieses iPhone noch lesen lässt.

    Lege ihn entsprechend ab und lösche ihn, sobald er nicht mehr gebraucht wird.
    """

    func listExports() throws -> [URL] {
        let entries = try fileManager.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return entries.filter { $0.lastPathComponent.hasPrefix("ContactSwap ") }
    }

    func deleteExport(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    // MARK: - Hilfen

    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH-mm"
        return f
    }()

    private func sanitized(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = String(name.unicodeScalars.map { forbidden.contains($0) ? "-" : Character($0) })
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
