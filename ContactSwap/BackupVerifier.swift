import Foundation

struct FieldMismatch: Identifiable {
    let id = UUID()
    let contactName: String
    let field: String
    let inAddressBook: String
    let inBackup: String
}

struct VerificationReport: Identifiable {
    let id = UUID()
    let checkedContacts: Int
    let checkedFields: Int
    let photosInAddressBook: Int
    let photosInBackup: Int
    var missingInBackup: [String] = []
    var onlyInBackup: [String] = []
    var mismatches: [FieldMismatch] = []
    var notesSkipped = false

    var isComplete: Bool {
        missingInBackup.isEmpty && onlyInBackup.isEmpty && mismatches.isEmpty
    }

    var summary: String {
        if isComplete {
            var text = "Vollständig: \(checkedContacts) Kontakte mit \(checkedFields) Einzelangaben stimmen exakt überein"
            text += photosInBackup > 0 ? ", davon \(photosInBackup) Fotos." : "."
            if notesSkipped {
                text += "\n\nNicht enthalten: Kontaktnotizen. Apple gibt diese nur mit einem gesondert beantragten Entitlement frei."
            }
            return text
        }

        var parts: [String] = []
        if !missingInBackup.isEmpty { parts.append("\(missingInBackup.count) Kontakte fehlen im Backup") }
        if !onlyInBackup.isEmpty { parts.append("\(onlyInBackup.count) Kontakte nur im Backup") }
        if !mismatches.isEmpty { parts.append("\(mismatches.count) abweichende Felder") }
        return parts.joined(separator: ", ") + "."
    }
}

/// Vergleicht ein Backup Feld für Feld mit dem aktuellen Adressbuch.
enum BackupVerifier {

    static func verify(backup: [Contact], against addressBook: [Contact], notesSkipped: Bool) -> VerificationReport {
        var byID: [String: Contact] = [:]
        for contact in backup { byID[contact.id] = contact }

        // Nach einem Restore vergibt iOS neue Identifier – dann greift der
        // inhaltliche Schlüssel als Rückfallebene.
        var byKey: [String: Contact] = [:]
        for contact in backup { byKey[contentKey(contact), default: contact] = contact }

        var report = VerificationReport(
            checkedContacts: addressBook.count,
            checkedFields: addressBook.reduce(0) { $0 + $1.fieldCount },
            photosInAddressBook: addressBook.filter { $0.imageData != nil }.count,
            photosInBackup: backup.filter { $0.imageData != nil || $0.photoPath != nil }.count
        )
        report.notesSkipped = notesSkipped

        var matchedBackupIDs: Set<String> = []

        for live in addressBook {
            guard let stored = byID[live.id] ?? byKey[contentKey(live)] else {
                report.missingInBackup.append(live.displayName)
                continue
            }
            matchedBackupIDs.insert(stored.id)
            report.mismatches.append(contentsOf: compare(live: live, stored: stored))
        }

        for stored in backup where !matchedBackupIDs.contains(stored.id) {
            report.onlyInBackup.append(stored.displayName)
        }

        return report
    }

    // MARK: - Feldvergleich

    private static func compare(live: Contact, stored: Contact) -> [FieldMismatch] {
        var result: [FieldMismatch] = []
        let name = live.displayName

        func check(_ field: String, _ a: String?, _ b: String?) {
            let left = a ?? "", right = b ?? ""
            guard left != right else { return }
            result.append(FieldMismatch(contactName: name, field: field,
                                        inAddressBook: left.isEmpty ? "leer" : left,
                                        inBackup: right.isEmpty ? "leer" : right))
        }

        check("Titel", live.namePrefix, stored.namePrefix)
        check("Vorname", live.givenName, stored.givenName)
        check("Zweiter Vorname", live.middleName, stored.middleName)
        check("Nachname", live.familyName, stored.familyName)
        check("Früherer Nachname", live.previousFamilyName, stored.previousFamilyName)
        check("Namenszusatz", live.nameSuffix, stored.nameSuffix)
        check("Spitzname", live.nickname, stored.nickname)
        check("Vorname (phonetisch)", live.phoneticGivenName, stored.phoneticGivenName)
        check("Zweitname (phonetisch)", live.phoneticMiddleName, stored.phoneticMiddleName)
        check("Nachname (phonetisch)", live.phoneticFamilyName, stored.phoneticFamilyName)
        check("Firma (phonetisch)", live.phoneticOrganizationName, stored.phoneticOrganizationName)
        check("Firma", live.organizationName, stored.organizationName)
        check("Abteilung", live.departmentName, stored.departmentName)
        check("Position", live.jobTitle, stored.jobTitle)
        check("Notiz", live.notes, stored.notes)

        if live.contactType != stored.contactType {
            check("Kontakttyp", "\(live.contactType)", "\(stored.contactType)")
        }
        if live.birthday != stored.birthday {
            check("Geburtstag", describe(live.birthday), describe(stored.birthday))
        }
        if live.nonGregorianBirthday != stored.nonGregorianBirthday {
            check("Geburtstag (nicht-gregorianisch)",
                  describe(live.nonGregorianBirthday), describe(stored.nonGregorianBirthday))
        }

        compareSets("Telefon", live.phones.map(descriptor), stored.phones.map(descriptor), name, &result)
        compareSets("E-Mail", live.emails.map(descriptor), stored.emails.map(descriptor), name, &result)
        compareSets("Adresse", live.addresses.map(descriptor), stored.addresses.map(descriptor), name, &result)
        compareSets("Webseite", live.urls.map(descriptor), stored.urls.map(descriptor), name, &result)
        compareSets("Social-Profil", live.socialProfiles.map(descriptor), stored.socialProfiles.map(descriptor), name, &result)
        compareSets("Messenger", live.instantMessages.map(descriptor), stored.instantMessages.map(descriptor), name, &result)
        compareSets("Beziehung", live.relations.map(descriptor), stored.relations.map(descriptor), name, &result)
        compareSets("Datum", live.dates.map(descriptor), stored.dates.map(descriptor), name, &result)

        // Fotos byteweise vergleichen.
        let livePhoto = live.imageData
        let storedPhoto = stored.imageData
        if livePhoto != storedPhoto {
            let a = livePhoto.map { "\($0.count) Bytes" } ?? "kein Foto"
            let b = storedPhoto.map { "\($0.count) Bytes" } ?? (stored.photoPath != nil ? "Datei nicht geladen" : "kein Foto")
            result.append(FieldMismatch(contactName: name, field: "Foto", inAddressBook: a, inBackup: b))
        }

        return result
    }

    private static func compareSets(_ field: String, _ live: [String], _ stored: [String],
                                    _ name: String, _ result: inout [FieldMismatch]) {
        guard Set(live) != Set(stored) else { return }
        result.append(FieldMismatch(
            contactName: name,
            field: field,
            inAddressBook: live.isEmpty ? "leer" : live.sorted().joined(separator: " | "),
            inBackup: stored.isEmpty ? "leer" : stored.sorted().joined(separator: " | ")
        ))
    }

    // MARK: - Beschreibungen (bewusst ohne Identifier, die sich beim Restore ändern)

    private static func descriptor(_ p: Phone) -> String { "\(p.label ?? "")=\(p.value)" }
    private static func descriptor(_ e: Email) -> String { "\(e.label ?? "")=\(e.value)" }
    private static func descriptor(_ t: LabeledText) -> String { "\(t.label ?? "")=\(t.value)" }
    private static func descriptor(_ d: LabeledDate) -> String { "\(d.label ?? "")=\(describe(d.components))" }

    private static func descriptor(_ a: Address) -> String {
        [a.label, a.street, a.subLocality, a.city, a.subAdministrativeArea,
         a.state, a.postalCode, a.country, a.isoCountryCode]
            .map { $0 ?? "" }
            .joined(separator: ",")
    }

    private static func descriptor(_ s: SocialProfile) -> String {
        [s.label, s.service, s.username, s.urlString, s.userIdentifier]
            .map { $0 ?? "" }
            .joined(separator: ",")
    }

    private static func descriptor(_ i: InstantMessage) -> String {
        [i.label, i.service, i.username].map { $0 ?? "" }.joined(separator: ",")
    }

    private static func describe(_ components: DateComponents?) -> String {
        guard let c = components else { return "leer" }
        let day = c.day.map { String(format: "%02d", $0) } ?? "??"
        let month = c.month.map { String(format: "%02d", $0) } ?? "??"
        let year = c.year.map(String.init) ?? "ohne Jahr"
        return "\(day).\(month).\(year)"
    }

    /// Inhaltlicher Schlüssel für den Abgleich, wenn die Identifier nicht mehr passen.
    private static func contentKey(_ c: Contact) -> String {
        let phones = c.phones.map(\.value).sorted().joined(separator: ",")
        let emails = c.emails.map(\.value).sorted().joined(separator: ",")
        return "\(c.givenName)|\(c.familyName)|\(c.organizationName ?? "")|\(phones)|\(emails)"
    }
}
