import SwiftUI

struct VerificationView: View {
    let report: VerificationReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: report.isComplete ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(report.isComplete ? .green : .orange)

                        Text(report.isComplete ? "Alle Daten übernommen" : "Abweichungen gefunden")
                            .font(.headline)
                    }
                    .padding(.vertical, 6)
                }

                Section("Geprüft") {
                    LabeledContent("Kontakte", value: "\(report.checkedContacts)")
                    LabeledContent("Einzelangaben", value: "\(report.checkedFields)")
                    LabeledContent("Fotos im Adressbuch", value: "\(report.photosInAddressBook)")
                    LabeledContent("Fotos im Backup", value: "\(report.photosInBackup)")
                }

                if !report.missingInBackup.isEmpty {
                    Section("Fehlen im Backup (\(report.missingInBackup.count))") {
                        ForEach(report.missingInBackup, id: \.self) { name in
                            Label(name, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                if !report.onlyInBackup.isEmpty {
                    Section("Nur im Backup (\(report.onlyInBackup.count))") {
                        ForEach(report.onlyInBackup, id: \.self) { name in
                            Label(name, systemImage: "questionmark.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                if !report.mismatches.isEmpty {
                    Section("Abweichende Felder (\(report.mismatches.count))") {
                        ForEach(report.mismatches) { mismatch in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mismatch.contactName)
                                    .font(.subheadline.bold())
                                Text(mismatch.field)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Adressbuch: \(mismatch.inAddressBook)")
                                    .font(.caption2)
                                Text("Backup: \(mismatch.inBackup)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if report.notesSkipped {
                    Section("Bekannte Einschränkung") {
                        Text("Kontaktnotizen sind nicht enthalten. Apple gibt das Feld nur mit dem gesondert zu beantragenden Entitlement „com.apple.developer.contacts.notes“ frei. Alle übrigen Felder werden vollständig gesichert.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Gesicherte Felder") {
                    Text(Self.coveredFields)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Prüfbericht")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private static let coveredFields = """
    Titel, Vorname, zweiter Vorname, Nachname, früherer Nachname, Namenszusatz, \
    Spitzname, alle vier phonetischen Namen, Firma, Abteilung, Position, Kontakttyp, \
    Geburtstag (auch ohne Jahresangabe), nicht-gregorianischer Geburtstag, weitere Datumsangaben, \
    Telefonnummern, E-Mail-Adressen, Postanschriften inkl. Ortsteil, Bezirk und ISO-Ländercode, \
    Webseiten, Social-Media-Profile, Messenger-Kennungen, Beziehungen sowie das Kontaktfoto \
    in Originalauflösung – jeweils mit den zugehörigen Bezeichnungen.
    """
}
