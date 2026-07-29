import Foundation

struct BackupMetadata: Codable, Identifiable {
    let id: String
    let name: String
    let timestamp: Date
    let contactCount: Int
    let photoCount: Int
    let totalPhotosSizeBytes: Int
    let appVersion: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalPhotosSizeBytes), countStyle: .file)
    }
}

struct BackupFile {
    let metadata: BackupMetadata
    let contacts: [Contact]
    let backupDirectoryURL: URL
}
