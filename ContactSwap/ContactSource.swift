import Foundation
import Contacts

/// Eine Quelle, aus der Kontakte auf dem Gerät stammen – lokal oder von einem Server.
///
/// Für den Swap ist das die wichtigste Information überhaupt: Alles, was nicht
/// `.local` ist, hängt an einem Server. Löschungen wandern dorthin und auf alle
/// Geräte, die daran hängen; manche Dienste spielen Kontakte auch wieder zurück.
struct ContactSource: Identifiable, Sendable {
    let id: String
    let name: String
    let kind: Kind
    let contactCount: Int

    enum Kind: Sendable {
        case local
        case exchange
        case cardDAV
        case unknown

        /// Alles außer der lokalen Ablage hängt an einem Server.
        var isSynced: Bool { self != .local }

        var label: String {
            switch self {
            case .local: return "lokal"
            case .exchange: return "Exchange"
            case .cardDAV: return "CardDAV"
            case .unknown: return "unbekannt"
            }
        }

        init(_ type: CNContainerType) {
            switch type {
            case .local: self = .local
            case .exchange: self = .exchange
            case .cardDAV: self = .cardDAV
            case .unassigned: self = .unknown
            @unknown default: self = .unknown
            }
        }
    }
}
