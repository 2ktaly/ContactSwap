import Foundation
import Contacts

final class ContactService {
    static let shared = ContactService()

    private let contactStore = CNContactStore()

    /// Wird auf `true` gesetzt, sobald ein Fetch mit Notizen fehlgeschlagen ist.
    /// Notizen erfordern das Apple-Entitlement `com.apple.developer.contacts.notes`.
    private(set) var notesUnavailable = false

    /// Alle Felder, die iOS pro Kontakt führt.
    private var baseKeys: [CNKeyDescriptor] {
        [
            CNContactIdentifierKey,
            CNContactTypeKey,
            CNContactNamePrefixKey,
            CNContactGivenNameKey,
            CNContactMiddleNameKey,
            CNContactFamilyNameKey,
            CNContactPreviousFamilyNameKey,
            CNContactNameSuffixKey,
            CNContactNicknameKey,
            CNContactPhoneticGivenNameKey,
            CNContactPhoneticMiddleNameKey,
            CNContactPhoneticFamilyNameKey,
            CNContactPhoneticOrganizationNameKey,
            CNContactOrganizationNameKey,
            CNContactDepartmentNameKey,
            CNContactJobTitleKey,
            CNContactBirthdayKey,
            CNContactNonGregorianBirthdayKey,
            CNContactDatesKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactPostalAddressesKey,
            CNContactUrlAddressesKey,
            CNContactSocialProfilesKey,
            CNContactInstantMessageAddressesKey,
            CNContactRelationsKey,
            CNContactImageDataKey
        ] as [CNKeyDescriptor]
    }

    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestContactsAccess() async -> Bool {
        switch authorizationStatus {
        case .authorized, .limited:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            do {
                return try await contactStore.requestAccess(for: .contacts)
            } catch {
                print("Fehler bei der Zugriffsanfrage: \(error)")
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Lesen

    /// Liest alle Kontakte samt sämtlicher Felder.
    ///
    /// Versucht zunächst, die Notizen mitzunehmen. Fehlt das dafür nötige
    /// Entitlement, wiederholt die Methode den Durchlauf ohne Notizen, statt
    /// das gesamte Backup scheitern zu lassen.
    func fetchAllContacts() throws -> [Contact] {
        if !notesUnavailable {
            do {
                return try enumerate(keys: baseKeys + [CNContactNoteKey as CNKeyDescriptor])
            } catch {
                notesUnavailable = true
                print("Notizen nicht verfügbar (Entitlement fehlt), sichere ohne Notizen: \(error)")
            }
        }
        return try enumerate(keys: baseKeys)
    }

    private func enumerate(keys: [CNKeyDescriptor]) throws -> [Contact] {
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName

        var contacts: [Contact] = []
        try contactStore.enumerateContacts(with: request) { cnContact, _ in
            contacts.append(Self.mapToContact(cnContact))
        }
        return contacts
    }

    func existingIdentifiers() throws -> Set<String> {
        let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
        var ids: Set<String> = []
        try contactStore.enumerateContacts(with: request) { contact, _ in
            ids.insert(contact.identifier)
        }
        return ids
    }

    // MARK: - Löschen

    @discardableResult
    func deleteContacts(byIdentifiers ids: [String]) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        let wanted = Set(ids)

        let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
        var found: [CNContact] = []
        try contactStore.enumerateContacts(with: request) { contact, _ in
            if wanted.contains(contact.identifier) { found.append(contact) }
        }

        guard !found.isEmpty else { return 0 }

        // Blockweise speichern – sehr große Sammel-Requests lehnt iOS ab.
        for chunk in found.chunked(into: 100) {
            let saveRequest = CNSaveRequest()
            for contact in chunk {
                guard let mutable = contact.mutableCopy() as? CNMutableContact else { continue }
                saveRequest.delete(mutable)
            }
            try contactStore.execute(saveRequest)
        }
        return found.count
    }

    // MARK: - Schreiben

    @discardableResult
    func addContacts(_ contacts: [Contact]) throws -> Int {
        guard !contacts.isEmpty else { return 0 }

        for chunk in contacts.chunked(into: 100) {
            let saveRequest = CNSaveRequest()
            for contact in chunk {
                saveRequest.add(Self.makeMutableContact(from: contact), toContainerWithIdentifier: nil)
            }
            try contactStore.execute(saveRequest)
        }
        return contacts.count
    }

    // MARK: - Lesen → Modell

    private static func mapToContact(_ c: CNContact) -> Contact {
        func optional(_ value: String) -> String? { value.isEmpty ? nil : value }

        // Auf Felder, die nicht angefordert wurden, wirft CNContact eine Exception.
        // Notizen sind der einzige Kandidat dafür.
        let note: String? = c.isKeyAvailable(CNContactNoteKey) ? optional(c.note) : nil

        return Contact(
            id: c.identifier,
            namePrefix: optional(c.namePrefix),
            givenName: c.givenName,
            middleName: optional(c.middleName),
            familyName: c.familyName,
            previousFamilyName: optional(c.previousFamilyName),
            nameSuffix: optional(c.nameSuffix),
            nickname: optional(c.nickname),
            phoneticGivenName: optional(c.phoneticGivenName),
            phoneticMiddleName: optional(c.phoneticMiddleName),
            phoneticFamilyName: optional(c.phoneticFamilyName),
            phoneticOrganizationName: optional(c.phoneticOrganizationName),
            organizationName: optional(c.organizationName),
            departmentName: optional(c.departmentName),
            jobTitle: optional(c.jobTitle),
            contactType: c.contactType.rawValue,
            birthday: c.birthday,
            nonGregorianBirthday: c.nonGregorianBirthday,
            dates: c.dates.map {
                LabeledDate(id: $0.identifier, components: $0.value as DateComponents, label: $0.label)
            },
            phones: c.phoneNumbers.map {
                Phone(id: $0.identifier, value: $0.value.stringValue, label: $0.label)
            },
            emails: c.emailAddresses.map {
                Email(id: $0.identifier, value: $0.value as String, label: $0.label)
            },
            addresses: c.postalAddresses.map { labeled in
                let a = labeled.value
                return Address(
                    id: labeled.identifier,
                    label: labeled.label,
                    street: optional(a.street),
                    subLocality: optional(a.subLocality),
                    city: optional(a.city),
                    subAdministrativeArea: optional(a.subAdministrativeArea),
                    state: optional(a.state),
                    postalCode: optional(a.postalCode),
                    country: optional(a.country),
                    isoCountryCode: optional(a.isoCountryCode)
                )
            },
            urls: c.urlAddresses.map {
                LabeledText(id: $0.identifier, value: $0.value as String, label: $0.label)
            },
            socialProfiles: c.socialProfiles.map { labeled in
                let p = labeled.value
                return SocialProfile(
                    id: labeled.identifier,
                    service: optional(p.service),
                    username: optional(p.username),
                    urlString: optional(p.urlString),
                    userIdentifier: optional(p.userIdentifier),
                    label: labeled.label
                )
            },
            instantMessages: c.instantMessageAddresses.map { labeled in
                InstantMessage(
                    id: labeled.identifier,
                    service: optional(labeled.value.service),
                    username: optional(labeled.value.username),
                    label: labeled.label
                )
            },
            relations: c.contactRelations.map {
                LabeledText(id: $0.identifier, value: $0.value.name, label: $0.label)
            },
            notes: note,
            photoPath: nil,
            imageData: c.imageData
        )
    }

    // MARK: - Modell → Schreiben

    private static func makeMutableContact(from contact: Contact) -> CNMutableContact {
        let m = CNMutableContact()

        m.contactType = CNContactType(rawValue: contact.contactType) ?? .person
        m.namePrefix = contact.namePrefix ?? ""
        m.givenName = contact.givenName
        m.middleName = contact.middleName ?? ""
        m.familyName = contact.familyName
        m.previousFamilyName = contact.previousFamilyName ?? ""
        m.nameSuffix = contact.nameSuffix ?? ""
        m.nickname = contact.nickname ?? ""

        m.phoneticGivenName = contact.phoneticGivenName ?? ""
        m.phoneticMiddleName = contact.phoneticMiddleName ?? ""
        m.phoneticFamilyName = contact.phoneticFamilyName ?? ""
        m.phoneticOrganizationName = contact.phoneticOrganizationName ?? ""

        m.organizationName = contact.organizationName ?? ""
        m.departmentName = contact.departmentName ?? ""
        m.jobTitle = contact.jobTitle ?? ""

        // DateComponents werden unverändert übernommen – ein Umweg über Date
        // würde Geburtstage ohne Jahresangabe verfälschen.
        m.birthday = contact.birthday
        m.nonGregorianBirthday = contact.nonGregorianBirthday
        m.dates = contact.dates.map {
            CNLabeledValue(label: $0.label, value: $0.components as NSDateComponents)
        }

        m.phoneNumbers = contact.phones.map {
            CNLabeledValue(label: $0.label, value: CNPhoneNumber(stringValue: $0.value))
        }
        m.emailAddresses = contact.emails.map {
            CNLabeledValue(label: $0.label, value: $0.value as NSString)
        }
        m.postalAddresses = contact.addresses.map { address in
            let p = CNMutablePostalAddress()
            p.street = address.street ?? ""
            p.subLocality = address.subLocality ?? ""
            p.city = address.city ?? ""
            p.subAdministrativeArea = address.subAdministrativeArea ?? ""
            p.state = address.state ?? ""
            p.postalCode = address.postalCode ?? ""
            p.country = address.country ?? ""
            p.isoCountryCode = address.isoCountryCode ?? ""
            return CNLabeledValue(label: address.label, value: p as CNPostalAddress)
        }
        m.urlAddresses = contact.urls.map {
            CNLabeledValue(label: $0.label, value: $0.value as NSString)
        }
        m.socialProfiles = contact.socialProfiles.map {
            CNLabeledValue(
                label: $0.label,
                value: CNSocialProfile(
                    urlString: $0.urlString,
                    username: $0.username,
                    userIdentifier: $0.userIdentifier,
                    service: $0.service
                )
            )
        }
        m.instantMessageAddresses = contact.instantMessages.map {
            CNLabeledValue(
                label: $0.label,
                value: CNInstantMessageAddress(username: $0.username ?? "", service: $0.service ?? "")
            )
        }
        m.contactRelations = contact.relations.map {
            CNLabeledValue(label: $0.label, value: CNContactRelation(name: $0.value))
        }

        if let notes = contact.notes {
            m.note = notes
        }

        m.imageData = contact.imageData

        return m
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
