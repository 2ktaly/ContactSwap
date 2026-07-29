import SwiftUI
import Contacts

struct SettingsView: View {
    @ObservedObject var store: AppStore

    @State private var showingSyncGuide = false
    @State private var showingDisguiseGuide = false
    @State private var selectedIcon = AppIconOption.all[0]

    var body: some View {
        NavigationStack {
            List {
                sourcesSection
                appearanceSection
                contactsSection
                statusSection
                sourceCodeSection
            }
            .navigationTitle("Einstellungen")
            .refreshable { await store.reloadAll() }
            .sheet(isPresented: $showingSyncGuide) { SyncGuideView() }
            .sheet(isPresented: $showingDisguiseGuide) { DisguiseGuideView() }
            .onAppear { selectedIcon = AppIconManager.current }
        }
    }

    // MARK: - Kontaktquellen

    private var sourcesSection: some View {
        Section {
            if store.sources.isEmpty {
                Text("Keine Quellen gelesen.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.sources) { source in
                    HStack(spacing: 12) {
                        Image(systemName: source.kind.isSynced ? "cloud.fill" : "iphone")
                            .foregroundStyle(source.kind.isSynced ? .orange : .green)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.name)
                            Text("\(source.kind.label) · \(source.contactCount) Kontakte")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Kontaktquellen")
        } footer: {
            Text(store.syncedSources.isEmpty
                 ? "Alle Kontakte liegen lokal auf diesem iPhone. Ein Swap wirkt nirgendwo sonst."
                 : "Orange markierte Quellen hängen an einem Server. Löschungen wirken dort und auf allen verbundenen Geräten – manche Dienste spielen Kontakte auch wieder zurück.")
        }
    }

    // MARK: - Erscheinungsbild

    private var appearanceSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(AppIconOption.all) { option in
                        Button {
                            change(to: option)
                        } label: {
                            VStack(spacing: 6) {
                                Image(option.previewAsset)
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 13))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 13)
                                            .strokeBorder(
                                                selectedIcon.id == option.id ? Color.accentColor : .clear,
                                                lineWidth: 3
                                            )
                                    }

                                Text(option.title)
                                    .font(.caption2)
                                    .foregroundStyle(selectedIcon.id == option.id ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }

            Button {
                showingDisguiseGuide = true
            } label: {
                Label("Namen tarnen", systemImage: "character.cursor.ibeam")
            }
        } header: {
            Text("Erscheinungsbild")
        } footer: {
            Text("Das Icon lässt sich hier wechseln. Den Namen unter dem Icon kann iOS nicht zur Laufzeit ändern – dafür gibt es den Weg über einen Kurzbefehl.")
        }
    }

    // MARK: - Kontakte

    private var contactsSection: some View {
        Section {
            Button {
                showingSyncGuide = true
            } label: {
                Label("Kontakt-Syncs abschalten", systemImage: "exclamationmark.triangle.fill")
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("iOS-Einstellungen öffnen", systemImage: "gear")
            }
        } header: {
            Text("Kontakte")
        } footer: {
            Text("Ist der Google-Kontakte-Sync aktiv, spielt Google gelöschte Kontakte binnen Minuten zurück – die Recherche wird dadurch unbrauchbar.")
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            LabeledContent("Kontakte im Adressbuch", value: "\(store.deviceContacts.count)")
            LabeledContent("Backups", value: "\(store.backups.count)")
            LabeledContent("Kontaktfreigabe", value: permissionLabel)
            LabeledContent("Speicherung", value: "lokal, verschlüsselt")
            LabeledContent("Version", value: Bundle.main.shortVersion)
        } header: {
            Text("Status")
        } footer: {
            Text("Backups liegen AES-verschlüsselt auf dem Gerät. Der Schlüssel steckt im Schlüsselbund dieses iPhones und verlässt es nicht – auch nicht über ein iCloud-Backup. Ein Passwort brauchst du nicht, der Gerätecode schützt ihn.")
        }
    }

    // MARK: - Quelltext

    private var sourceCodeSection: some View {
        Section {
            Link(destination: Self.repositoryURL) {
                Label("Quelltext auf GitHub", systemImage: "curlybraces")
            }
        } header: {
            Text("Nachprüfbarkeit")
        } footer: {
            Text("Der vollständige Quelltext ist einsehbar – so lässt sich prüfen, dass die App keine Daten verschickt. Einsehbar heißt nicht frei verwendbar: Vervielfältigung und Weitergabe sind laut Lizenz untersagt.")
        }
    }

    static let repositoryURL = URL(string: "https://github.com/2ktaly/ContactSwap")!

    // MARK: - Hilfen

    private func change(to option: AppIconOption) {
        let previous = selectedIcon
        selectedIcon = option

        Task {
            do {
                try await AppIconManager.apply(option)
            } catch {
                selectedIcon = previous
                store.alert = .error("Icon konnte nicht gewechselt werden", error)
            }
        }
    }

    private var permissionLabel: String {
        switch store.permission {
        case .authorized: return "erteilt"
        case .limited: return "eingeschränkt"
        case .denied: return "verweigert"
        case .restricted: return "gesperrt"
        case .notDetermined: return "nicht erteilt"
        @unknown default: return "unbekannt"
        }
    }
}
