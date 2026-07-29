import Foundation

/// Vollständige Abbildung eines iOS-Kontakts (CNContact).
///
/// Nicht enthalten ist einzig `note`: Apple verlangt für Kontaktnotizen seit
/// iOS 13 das gesondert zu beantragende Entitlement
/// `com.apple.developer.contacts.notes`. Ohne dieses schlägt bereits das Auslesen
/// fehl – siehe `ContactService.keysToFetch`.
struct Contact: Codable, Identifiable {
    let id: String

    // Name
    var namePrefix: String?
    let givenName: String
    var middleName: String?
    let familyName: String
    var previousFamilyName: String?
    var nameSuffix: String?
    var nickname: String?

    // Phonetik
    var phoneticGivenName: String?
    var phoneticMiddleName: String?
    var phoneticFamilyName: String?
    var phoneticOrganizationName: String?

    // Beruf
    var organizationName: String?
    var departmentName: String?
    var jobTitle: String?

    /// 0 = Person, 1 = Organisation (entspricht CNContactType)
    var contactType: Int = 0

    // Daten
    var birthday: DateComponents?
    var nonGregorianBirthday: DateComponents?
    var dates: [LabeledDate] = []

    // Kommunikation
    var phones: [Phone] = []
    var emails: [Email] = []
    var addresses: [Address] = []
    var urls: [LabeledText] = []
    var socialProfiles: [SocialProfile] = []
    var instantMessages: [InstantMessage] = []
    var relations: [LabeledText] = []

    /// Nur gesetzt, solange die Notizen-Berechtigung vorliegt.
    var notes: String?

    /// Dateiname des Fotos innerhalb des Backup-Verzeichnisses.
    var photoPath: String?

    /// Bilddaten in Originalgröße. Bewusst nicht in der JSON – Fotos liegen
    /// als eigene Dateien neben der contacts.json.
    var imageData: Data?

    var displayName: String {
        let parts = [givenName, familyName].filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        if let nickname, !nickname.isEmpty { return nickname }
        if let organizationName, !organizationName.isEmpty { return organizationName }
        return "Ohne Namen"
    }

    /// Anzahl der belegten Einzelangaben – Grundlage für die Backup-Prüfung.
    var fieldCount: Int {
        var count = 0
        for value in [namePrefix, middleName, previousFamilyName, nameSuffix, nickname,
                      phoneticGivenName, phoneticMiddleName, phoneticFamilyName,
                      phoneticOrganizationName, organizationName, departmentName,
                      jobTitle, notes] {
            if let value, !value.isEmpty { count += 1 }
        }
        if !givenName.isEmpty { count += 1 }
        if !familyName.isEmpty { count += 1 }
        if birthday != nil { count += 1 }
        if nonGregorianBirthday != nil { count += 1 }
        if imageData != nil { count += 1 }
        count += dates.count + phones.count + emails.count + addresses.count
        count += urls.count + socialProfiles.count + instantMessages.count + relations.count
        return count
    }

    enum CodingKeys: String, CodingKey {
        case id, namePrefix, givenName, middleName, familyName, previousFamilyName
        case nameSuffix, nickname, phoneticGivenName, phoneticMiddleName
        case phoneticFamilyName, phoneticOrganizationName, organizationName
        case departmentName, jobTitle, contactType, birthday, nonGregorianBirthday
        case dates, phones, emails, addresses, urls, socialProfiles
        case instantMessages, relations, notes, photoPath
    }
}

// MARK: - Teilwerte

struct Phone: Codable, Identifiable, Equatable {
    let id: String
    let value: String
    let label: String?
}

struct Email: Codable, Identifiable, Equatable {
    let id: String
    let value: String
    let label: String?
}

/// Beliebiger beschrifteter Textwert – für URLs und Beziehungen.
struct LabeledText: Codable, Identifiable, Equatable {
    let id: String
    let value: String
    let label: String?
}

struct LabeledDate: Codable, Identifiable, Equatable {
    let id: String
    let components: DateComponents
    let label: String?
}

struct SocialProfile: Codable, Identifiable, Equatable {
    let id: String
    let service: String?
    let username: String?
    let urlString: String?
    let userIdentifier: String?
    let label: String?
}

struct InstantMessage: Codable, Identifiable, Equatable {
    let id: String
    let service: String?
    let username: String?
    let label: String?
}

struct Address: Codable, Identifiable, Equatable {
    let id: String
    let label: String?
    let street: String?
    let subLocality: String?
    let city: String?
    let subAdministrativeArea: String?
    let state: String?
    let postalCode: String?
    let country: String?
    let isoCountryCode: String?
}
