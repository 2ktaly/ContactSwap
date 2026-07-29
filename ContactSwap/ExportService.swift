import Foundation

class ExportService {
    static let shared = ExportService()

    private let fileManager = FileManager.default

    /// Der Dokumente-Ordner der App. Über die Dateien-App sichtbar, sobald
    /// UIFileSharingEnabled gesetzt ist – von dort lässt sich der Export auf
    /// iCloud, NAS oder Rechner kopieren.
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Legt eine vollständige Kopie des Backups (inkl. Fotos) in "Dokumente" ab.
    @discardableResult
    func exportBackup(_ backup: BackupFile) throws -> URL {
        let stamp = Self.filenameFormatter.string(from: backup.metadata.timestamp)
        let folderName = "ContactSwap \(sanitized(backup.metadata.name)) \(stamp)"
        let destination = documentsDirectory.appendingPathComponent(folderName, isDirectory: true)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: backup.backupDirectoryURL, to: destination)
        return destination
    }

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
