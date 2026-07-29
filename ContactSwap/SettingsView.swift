import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var showingGoogleGuide = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingGoogleGuide = true
                    } label: {
                        Label("Google-Sync deaktivieren", systemImage: "exclamationmark.triangle.fill")
                    }
                } header: {
                    Text("Vor der Recherche")
                } footer: {
                    Text("Ist der Google-Kontakte-Sync aktiv, spielt Google gelöschte Kontakte binnen Minuten zurück – die Recherche wird dadurch unbrauchbar.")
                }

                Section("Ablauf") {
                    StepRow(number: 1, text: "Backup unter „Sichern“ anlegen und in die Dateien-App exportieren.")
                    StepRow(number: 2, text: "Google-Sync in den iOS-Einstellungen abschalten.")
                    StepRow(number: 3, text: "Unter „Swap“ den Testkontakt auswählen und das Adressbuch leeren.")
                    StepRow(number: 4, text: "In der Ziel-App Kontaktfreigabe erteilen und die Vorschläge auswerten.")
                    StepRow(number: 5, text: "Unter „Zurück“ das Backup wieder einspielen.")
                }

                Section("Status") {
                    LabeledContent("Kontakte im Adressbuch", value: "\(store.deviceContacts.count)")
                    LabeledContent("Backups", value: "\(store.backups.count)")
                    LabeledContent("Version", value: Bundle.main.shortVersion)
                    LabeledContent("Speicherung", value: "lokal, unverschlüsselt")
                }

                Section {
                    Text("Kontakte werden nie endgültig gelöscht: Vor jedem Leeren legt die App automatisch ein vollständiges Backup an.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Info")
            .sheet(isPresented: $showingGoogleGuide) {
                GoogleSyncGuideView()
            }
        }
    }
}

struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())

            Text(text)
                .font(.callout)
        }
        .padding(.vertical, 2)
    }
}

struct GoogleSyncGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Google synchronisiert Kontakte in beide Richtungen. Löschst du sie auf dem iPhone, kann Google sie vom Server zurückspielen – oft innerhalb weniger Minuten.")
                        .font(.callout)
                }

                Section("So schaltest du den Sync ab") {
                    StepRow(number: 1, text: "Einstellungen → Apps → Kontakte → Kontakte-Accounts")
                    StepRow(number: 2, text: "Google-Account antippen")
                    StepRow(number: 3, text: "Schalter „Kontakte“ ausschalten")
                    StepRow(number: 4, text: "„Von meinem iPhone löschen“ bestätigen – die Daten bleiben bei Google erhalten")
                }

                Section("Danach wieder einschalten") {
                    Text("Denselben Weg gehen und den Schalter „Kontakte“ wieder aktivieren. Warte damit, bis du das Backup zurückgespielt hast, sonst können Dubletten entstehen.")
                        .font(.callout)
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Einstellungen öffnen", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("Google-Sync")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
