import SwiftUI

/// Erklärt den Ablauf einer Recherche. Erreichbar über das „i“ oben rechts
/// auf der Swap-Seite – dort, wo die Fragen tatsächlich aufkommen.
struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingGoogleGuide = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Wähle die Kontakte aus, die im Adressbuch bleiben sollen. Alle anderen werden entfernt – vorher legt die App automatisch ein vollständiges Backup an.")
                        .font(.callout)
                }

                Section("Ablauf") {
                    StepRow(number: 1, text: "Google-Sync in den iOS-Einstellungen abschalten.")
                    StepRow(number: 2, text: "Unter „Swap“ die Kontakte auswählen, die bleiben sollen, und auf „Leeren“ tippen.")
                    StepRow(number: 3, text: "In der Ziel-App die Kontaktfreigabe erteilen und die Vorschläge auswerten.")
                    StepRow(number: 4, text: "Unter „Zurück“ das Backup wieder einspielen.")
                }

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

                Section {
                    Text("Kontakte werden nie endgültig gelöscht: Vor jedem Leeren legt die App automatisch ein vollständiges Backup an. Unter „Zurück“ lässt es sich jederzeit einspielen, prüfen oder in die Dateien-App exportieren.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Wo die Daten liegen") {
                    Text("Backups liegen AES-verschlüsselt im Speicher der App. Der Schlüssel steckt im Schlüsselbund dieses iPhones, ist an dieses Gerät gebunden und wandert in kein iCloud-Backup. Eine kopierte Backup-Datei ist auf einem anderen Gerät wertlos.")
                        .font(.callout)

                    Text("Der Export in die Dateien-App ist bewusst unverschlüsselt – sonst wäre er ohne dieses iPhone nicht mehr lesbar und als Sicherung wertlos. Exportierte Ordner also bewusst ablegen und wieder löschen.")
                        .font(.callout)
                }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

/// iOS lässt den Namen unter dem Icon zur Laufzeit nicht ändern – er steckt
/// als `CFBundleDisplayName` fest im Programm. Ein Kurzbefehl auf dem
/// Home-Bildschirm umgeht das: Er trägt einen frei wählbaren Namen und ein
/// frei wählbares Bild und öffnet trotzdem diese App.
struct DisguiseGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Den Namen unter dem Icon kann keine App auf dem iPhone selbst ändern – iOS sieht dafür keinen Weg vor. Über einen Kurzbefehl lässt sich aber eine Kachel anlegen, die Namen und Bild frei wählt und beim Antippen diese App öffnet.")
                        .font(.callout)
                }

                Section("Kachel anlegen") {
                    StepRow(number: 1, text: "Kurzbefehle-App öffnen und einen neuen Kurzbefehl anlegen.")
                    StepRow(number: 2, text: "Aktion „App öffnen“ hinzufügen und diese App auswählen.")
                    StepRow(number: 3, text: "Oben auf den Namen tippen → „Zum Home-Bildschirm hinzufügen“.")
                    StepRow(number: 4, text: "Dort Wunschnamen eintragen und über das Symbol ein beliebiges Foto wählen.")
                }

                Section("App selbst verbergen") {
                    StepRow(number: 1, text: "Auf dieses App-Icon lange tippen → „App entfernen“ → „Vom Home-Bildschirm entfernen“.")
                    StepRow(number: 2, text: "Die App bleibt in der App-Mediathek und über die Suche auffindbar.")
                }

                Section {
                    Text("Was bleibt: In den iOS-Einstellungen, in der App-Mediathek und in der Suche steht weiterhin der echte Name. Wer gezielt sucht, findet die App – die Kachel schützt gegen den flüchtigen Blick, nicht gegen eine Durchsuchung.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Namen tarnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    InfoView()
}
