import Testing
import Foundation
import Contacts
@testable import ContactSwap

/// Prüft, dass wirklich jede Kontaktangabe erhalten bleibt – einmal über die
/// Backup-Datei und einmal über das echte iOS-Adressbuch.
struct ContactSwapTests {

    // MARK: - Testdaten

    /// Ein Kontakt, bei dem jedes von ContactSwap unterstützte Feld belegt ist.
    static func fullyPopulatedContact(id: String = UUID().uuidString) -> Contact {
        Contact(
            id: id,
            namePrefix: "Dr.",
            givenName: "Erika",
            middleName: "Maria",
            familyName: "Mustermann",
            previousFamilyName: "Schmidt",
            nameSuffix: "M.A.",
            nickname: "Rike",
            phoneticGivenName: "E-ri-ka",
            phoneticMiddleName: "Ma-ri-a",
            phoneticFamilyName: "Mus-ter-mann",
            phoneticOrganizationName: "Bei-spiel",
            organizationName: "Beispiel GmbH",
            departmentName: "Ermittlungen",
            jobTitle: "Sachbearbeiterin",
            contactType: 0,
            birthday: DateComponents(year: 1985, month: 3, day: 14),
            nonGregorianBirthday: nil,
            dates: [
                LabeledDate(id: "d1", components: DateComponents(year: 2010, month: 6, day: 1),
                            label: CNLabelDateAnniversary)
            ],
            phones: [
                Phone(id: "p1", value: "+49 171 1234567", label: CNLabelPhoneNumberMobile),
                Phone(id: "p2", value: "+49 221 987654", label: CNLabelWork)
            ],
            emails: [
                Email(id: "e1", value: "erika@example.com", label: CNLabelHome),
                Email(id: "e2", value: "e.mustermann@firma.de", label: CNLabelWork)
            ],
            addresses: [
                Address(id: "a1", label: CNLabelHome, street: "Musterweg 3", subLocality: "Altstadt",
                        city: "Köln", subAdministrativeArea: "Köln", state: "NRW",
                        postalCode: "50667", country: "Deutschland", isoCountryCode: "DE")
            ],
            urls: [
                LabeledText(id: "u1", value: "https://example.com", label: CNLabelURLAddressHomePage)
            ],
            socialProfiles: [
                SocialProfile(id: "s1", service: "Twitter", username: "erika_m",
                              urlString: "https://twitter.com/erika_m",
                              userIdentifier: "12345", label: nil)
            ],
            instantMessages: [
                InstantMessage(id: "i1", service: "Skype", username: "erika.skype", label: nil)
            ],
            relations: [
                LabeledText(id: "r1", value: "Max Mustermann", label: CNLabelContactRelationSpouse)
            ],
            notes: nil,
            photoPath: nil,
            imageData: pngData()
        )
    }

    /// Kleines, aber echtes PNG – belegt, dass Bilddaten unverändert durchlaufen.
    static func pngData() -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAKklEQVQoU2NkYGD4z0AEYBxVSFJAAQDS7wH9abwZ0wAAAABJRU5ErkJggg=="
        return Data(base64Encoded: base64)!
    }

    // MARK: - Backup-Datei

    @Test("Backup und erneutes Laden erhalten jedes Feld")
    func backupRoundTripKeepsEveryField() async throws {
        let original = Self.fullyPopulatedContact()

        let backup = try BackupService.shared.createBackup(name: "Testlauf", contacts: [original])
        defer { try? BackupService.shared.deleteBackup(byID: backup.metadata.id) }

        let reloaded = try BackupService.shared.loadBackup(byID: backup.metadata.id)
        let restored = try #require(reloaded.contacts.first)

        let report = BackupVerifier.verify(backup: [restored], against: [original], notesSkipped: false)

        #expect(report.isComplete, "Abweichungen: \(report.mismatches.map(\.field))")
        #expect(restored.imageData == original.imageData, "Foto wurde verändert")
        #expect(reloaded.metadata.photoCount == 1)
        #expect(original.fieldCount >= 20, "Testkontakt deckt zu wenige Felder ab")
    }

    @Test("Geburtstag ohne Jahresangabe bleibt erhalten")
    func birthdayWithoutYearSurvives() async throws {
        var contact = Self.fullyPopulatedContact()
        contact.birthday = DateComponents(month: 7, day: 28)

        let backup = try BackupService.shared.createBackup(name: "Geburtstag", contacts: [contact])
        defer { try? BackupService.shared.deleteBackup(byID: backup.metadata.id) }

        let restored = try #require(try BackupService.shared.loadBackup(byID: backup.metadata.id).contacts.first)

        #expect(restored.birthday?.day == 28)
        #expect(restored.birthday?.month == 7)
        #expect(restored.birthday?.year == nil, "Ein Jahr wurde erfunden")
    }

    // MARK: - Echtes Adressbuch

    @Test("Schreiben ins Adressbuch und Zurücklesen verliert keine Angabe")
    func addressBookRoundTripKeepsEveryField() async throws {
        guard await ContactService.shared.requestContactsAccess() else {
            Issue.record("Kein Kontaktzugriff – Test übersprungen")
            return
        }

        let original = Self.fullyPopulatedContact()
        let before = try ContactService.shared.existingIdentifiers()

        try ContactService.shared.addContacts([original])

        let after = try ContactService.shared.fetchAllContacts()
        let newOnes = after.filter { !before.contains($0.id) }
        defer { try? ContactService.shared.deleteContacts(byIdentifiers: newOnes.map(\.id)) }

        let written = try #require(newOnes.first, "Kontakt wurde nicht angelegt")

        // Der Identifier wird von iOS neu vergeben – der Verifier gleicht
        // deshalb über den Inhalt ab.
        let report = BackupVerifier.verify(backup: [original], against: [written],
                                           notesSkipped: ContactService.shared.notesUnavailable)

        let details = report.mismatches
            .map { "\($0.field): Adressbuch=\($0.inAddressBook) / Backup=\($0.inBackup)" }
            .joined(separator: "\n")
        #expect(report.isComplete, "Verluste beim Schreiben ins Adressbuch:\n\(details)")
    }
}
