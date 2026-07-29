import SwiftUI

struct SwapView: View {
    @ObservedObject var store: AppStore

    @State private var keptIDs: Set<String> = []
    @State private var searchText = ""
    @State private var showConfirmation = false
    @State private var showingInfo = false

    var body: some View {
        NavigationStack {
            Group {
                if store.deviceContacts.isEmpty {
                    ContentUnavailableView(
                        "Adressbuch ist leer",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Es sind keine Kontakte auf dem Gerät. Über „Zurück“ lässt sich ein Backup einspielen.")
                    )
                } else {
                    contactList
                }
            }
            .navigationTitle("Swap")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Info zum Ablauf")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Leeren") { showConfirmation = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(store.deviceContacts.isEmpty || store.busyMessage != nil)
                }
            }
            .searchable(text: $searchText, prompt: "Kontakt suchen")
            .sheet(isPresented: $showingInfo) {
                InfoView()
            }
            .confirmationDialog(
                "Adressbuch leeren?",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sichern und leeren", role: .destructive) {
                    let kept = keptIDs
                    Task { await store.swap(keeping: kept) }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text(confirmationMessage)
            }
            .refreshable { await store.reloadDeviceContacts() }
        }
    }

    private var contactList: some View {
        List {
            Section {
                LocalOnlyRow()

                if !store.syncedSources.isEmpty {
                    SyncWarningRow(sources: store.syncedSources)
                }
            }

            Section("Behalten (\(keptIDs.count) von \(store.deviceContacts.count))") {
                ForEach(filteredContacts) { contact in
                    Button {
                        toggle(contact.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: keptIDs.contains(contact.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(keptIDs.contains(contact.id) ? Color.accentColor : Color.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.displayName)
                                    .foregroundStyle(.primary)
                                if let phone = contact.phones.first?.value {
                                    Text(phone)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredContacts: [Contact] {
        guard !searchText.isEmpty else { return store.deviceContacts }
        return store.deviceContacts.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(searchText)
                || contact.phones.contains { $0.value.contains(searchText) }
        }
    }

    private var confirmationMessage: String {
        let remove = store.deviceContacts.count - keptIDs.count
        var message: String

        if keptIDs.isEmpty {
            message = "Alle \(store.deviceContacts.count) Kontakte werden entfernt. Ein Backup wird vorher automatisch angelegt – nichts geht verloren."
        } else {
            message = "\(remove) Kontakte werden entfernt, \(keptIDs.count) bleiben. Ein Backup wird vorher automatisch angelegt."
        }

        // Ohne diesen Zusatz wirkt der Swap wie eine rein lokale Aktion –
        // bei aktiven Server-Quellen ist er das ausdrücklich nicht.
        if !store.syncedSources.isEmpty {
            let names = store.syncedSources.map(\.name).joined(separator: ", ")
            message += "\n\nAchtung: \(names) hängt an einem Server. Die Löschung wirkt dort und auf allen verbundenen Geräten."
        }

        return message
    }

    private func toggle(_ id: String) {
        if keptIDs.contains(id) {
            keptIDs.remove(id)
        } else {
            keptIDs.insert(id)
        }
    }
}

/// Die zentrale Zusage der App, gut sichtbar dort, wo gelöscht wird.
struct LocalOnlyRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.iphone")
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text("Ausschließlich lokal")
                    .font(.subheadline.bold())
                Text("Backups liegen nur auf diesem iPhone. Die App sendet nichts ins Netz.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Warnt, sobald Kontakte an einem Server hängen – dann reicht das Backup
/// allein nicht, weil die Löschung über das Gerät hinaus wirkt.
struct SyncWarningRow: View {
    let sources: [ContactSource]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(sources.count == 1 ? "Eine Quelle synchronisiert" : "\(sources.count) Quellen synchronisieren")
                    .font(.subheadline.bold())
                Text("\(names) – Löschungen wirken dort und auf allen verbundenen Geräten. Unter „Einstellungen“ nachsehen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var names: String {
        sources.map { "\($0.name) (\($0.kind.label))" }.joined(separator: ", ")
    }
}
