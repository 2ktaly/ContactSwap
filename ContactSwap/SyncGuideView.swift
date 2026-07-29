import SwiftUI

/// Eine Kontaktquelle, die einen Swap überdauern oder rückgängig machen kann.
struct SyncProvider: Identifiable {
    let id = UUID()
    let name: String
    let risk: Risk
    let summary: String
    let steps: [String]

    enum Risk {
        case returnsContacts   // spielt gelöschte Kontakte zurück
        case spreadsDeletion   // löscht überall mit
        case harmless

        var symbol: String {
            switch self {
            case .returnsContacts: return "arrow.uturn.backward.circle.fill"
            case .spreadsDeletion: return "arrow.triangle.branch"
            case .harmless: return "checkmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .returnsContacts: return .red
            case .spreadsDeletion: return .orange
            case .harmless: return .green
            }
        }

        var label: String {
            switch self {
            case .returnsContacts: return "spielt Kontakte zurück"
            case .spreadsDeletion: return "löscht überall mit"
            case .harmless: return "unkritisch"
            }
        }
    }
}

/// Zeigt alle Wege auf, über die Kontakte auf dem iPhone landen können.
///
/// iCloud steht bewusst allein oben: Es ist bei fast jedem eingeschaltet und
/// verhält sich anders als die übrigen Dienste – es spielt nichts zurück,
/// sondern trägt die Löschung auf alle Apple-Geräte weiter.
struct SyncGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Alles, was hier aktiv ist, überlebt einen Swap oder macht ihn rückgängig. Welche Quellen auf diesem iPhone tatsächlich laufen, steht unter „Einstellungen“ in der App.")
                        .font(.callout)
                }

                icloudSection

                Section("Weitere Dienste") {
                    ForEach(Self.providers) { provider in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(provider.summary)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                ForEach(Array(provider.steps.enumerated()), id: \.offset) { index, step in
                                    StepRow(number: index + 1, text: step)
                                }
                            }
                            .padding(.top, 4)
                        } label: {
                            ProviderLabel(provider: provider)
                        }
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("iOS-Einstellungen öffnen", systemImage: "gear")
                    }
                } header: {
                    Text("Alle auf einen Blick")
                } footer: {
                    Text("Unter „Einstellungen → Apps → Kontakte → Kontakte-Accounts“ stehen sämtliche Quellen untereinander. Jeder Eintrag mit aktivem Schalter „Kontakte“ ist eine davon.")
                }
            }
            .navigationTitle("Kontakte-Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - iCloud

    private var icloudSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                ProviderLabel(provider: Self.icloud)

                Text(Self.icloud.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ForEach(Array(Self.icloud.steps.enumerated()), id: \.offset) { index, step in
                    StepRow(number: index + 1, text: step)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("iCloud – fast immer aktiv")
        } footer: {
            Text("iCloud hat ein Sicherheitsnetz, das die anderen Dienste nicht bieten: Auf iCloud.com unter „Datenschutz → Kontakte wiederherstellen“ liegen Archive der letzten Wochen.")
        }
    }

    // MARK: - Daten

    static let icloud = SyncProvider(
        name: "iCloud",
        risk: .spreadsDeletion,
        summary: "Spielt nichts zurück, trägt die Löschung aber auf iPad, Mac und Apple Watch weiter. Da iCloud bei fast jedem eingeschaltet ist, ist das der häufigste Fall – und der einzige, bei dem ein Swap sofort andere Geräte trifft.",
        steps: [
            "Einstellungen öffnen und ganz oben auf den eigenen Namen tippen.",
            "„iCloud“ → „Kontakte“ (gegebenenfalls erst „Alle anzeigen“).",
            "Schalter ausschalten und „Auf meinem iPhone behalten“ wählen.",
            "Nach der Recherche wieder einschalten – dann auf Dubletten achten."
        ]
    )

    static let providers: [SyncProvider] = [
        SyncProvider(
            name: "Google",
            risk: .returnsContacts,
            summary: "Synchronisiert in beide Richtungen und stellt gelöschte Kontakte oft binnen Minuten vom Server wieder her. Der klassische Fall, in dem eine Recherche unbrauchbar wird.",
            steps: [
                "Einstellungen → Apps → Kontakte → Kontakte-Accounts.",
                "Google-Account antippen.",
                "Schalter „Kontakte“ ausschalten.",
                "„Von meinem iPhone löschen“ bestätigen – bei Google bleibt alles erhalten."
            ]
        ),
        SyncProvider(
            name: "Exchange / Microsoft 365",
            risk: .returnsContacts,
            summary: "Dienstliche Postfächer. Ob gelöschte Kontakte zurückkommen, hängt von den Server-Richtlinien ab – verlassen sollte man sich darauf nicht.",
            steps: [
                "Einstellungen → Apps → Kontakte → Kontakte-Accounts.",
                "Exchange- oder Microsoft-365-Account antippen.",
                "Schalter „Kontakte“ ausschalten."
            ]
        ),
        SyncProvider(
            name: "CardDAV (Nextcloud, IONOS, Fastmail …)",
            risk: .returnsContacts,
            summary: "Die stille Kategorie: einmal eingerichtet, läuft sie unauffällig weiter. Eigene Server wie Nextcloud gehören genauso dazu wie CardDAV bei Mail-Anbietern.",
            steps: [
                "Einstellungen → Apps → Kontakte → Kontakte-Accounts.",
                "Jeden Eintrag prüfen, der nicht Apple, Google oder Exchange ist.",
                "Schalter „Kontakte“ ausschalten."
            ]
        ),
        SyncProvider(
            name: "Yahoo, AOL, Outlook.com",
            risk: .returnsContacts,
            summary: "Eigene Account-Typen in iOS mit jeweils eigenem Kontakte-Schalter. Verhalten sich wie Google.",
            steps: [
                "Einstellungen → Apps → Kontakte → Kontakte-Accounts.",
                "Account antippen und Schalter „Kontakte“ ausschalten."
            ]
        ),
        SyncProvider(
            name: "LDAP und SIM-Karte",
            risk: .harmless,
            summary: "Beide brauchen keine Beachtung: LDAP durchsucht nur ein Verzeichnis, ohne etwas ins Adressbuch zu schreiben. SIM-Kontakte werden einmalig importiert und synchronisieren nicht.",
            steps: []
        )
    ]
}

private struct ProviderLabel: View {
    let provider: SyncProvider

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: provider.risk.symbol)
                .foregroundStyle(provider.risk.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(provider.name)
                    .font(.subheadline.weight(.semibold))
                Text(provider.risk.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SyncGuideView()
}
