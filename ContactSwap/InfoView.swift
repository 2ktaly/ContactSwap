import SwiftUI

/// Erklärt den Ablauf einer Recherche. Erreichbar über das „i“ oben rechts
/// auf der Swap-Seite – dort, wo die Fragen tatsächlich aufkommen.
struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingSyncGuide = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Wähle die Kontakte aus, die im Adressbuch bleiben sollen. Alle anderen werden entfernt – vorher legt die App automatisch ein vollständiges Backup an.")
                        .font(.callout)
                }

                Section("Ablauf") {
                    StepRow(number: 1, text: "Alle Kontakt-Syncs abschalten – iCloud zuerst, es ist fast immer aktiv.")
                    StepRow(number: 2, text: "Unter „Swap“ die Kontakte auswählen, die bleiben sollen, und auf „Leeren“ tippen.")
                    StepRow(number: 3, text: "In der Ziel-App die Kontaktfreigabe erteilen und die Vorschläge auswerten.")
                    StepRow(number: 4, text: "Unter „Zurück“ das Backup wieder einspielen, dann die Syncs wieder einschalten.")
                }

                Section {
                    Button {
                        showingSyncGuide = true
                    } label: {
                        Label("Kontakt-Syncs abschalten", systemImage: "exclamationmark.triangle.fill")
                    }
                } header: {
                    Text("Vor der Recherche")
                } footer: {
                    Text("Zwei Gefahren, die sich unterscheiden: iCloud trägt die Löschung auf alle Apple-Geräte weiter. Google, Exchange und CardDAV-Konten spielen Kontakte dagegen vom Server zurück und machen die Recherche unbrauchbar. Welche Quellen hier laufen, steht unter „Einstellungen“.")
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
            .sheet(isPresented: $showingSyncGuide) {
                SyncGuideView()
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
