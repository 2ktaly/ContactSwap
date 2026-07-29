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

#Preview {
    InfoView()
}
