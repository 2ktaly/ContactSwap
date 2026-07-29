import SwiftUI

struct SwapView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var purchases: PurchaseStore

    @State private var keptIDs: Set<String> = []
    @State private var searchText = ""
    @State private var showConfirmation = false
    @State private var showingInfo = false

    /// Gesperrt, sobald der Gratis-Swap verbraucht und nichts gekauft ist.
    private var isBlocked: Bool {
        !purchases.isPurchased && store.remainingFreeSwaps == 0
    }

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
                    Button("Leeren") {
                        withAnimation { showConfirmation.toggle() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isBlocked ? .gray : .blue)
                    .disabled(store.deviceContacts.isEmpty || store.busyMessage != nil || isBlocked)
                }
            }
            .searchable(text: $searchText, prompt: "Kontakt suchen")
            .sheet(isPresented: $showingInfo) {
                InfoView()
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

                if !purchases.isPurchased {
                    FreeVersionRow(remaining: store.remainingFreeSwaps)
                }
            }

            if showConfirmation {
                confirmationSection
            }

            if !keptContacts.isEmpty {
                Section {
                    ForEach(keptContacts) { contact in
                        Button {
                            toggle(contact.id)
                        } label: {
                            ContactRow(contact: contact, isKept: true)
                        }
                    }
                } header: {
                    Text("Behalten (\(keptContacts.count))")
                } footer: {
                    Text("Diese Kontakte bleiben im Adressbuch. Zum Entfernen aus der Auswahl antippen.")
                }
            }

            Section("Alle Kontakte (\(store.deviceContacts.count))") {
                ForEach(filteredContacts) { contact in
                    Button {
                        toggle(contact.id)
                    } label: {
                        ContactRow(contact: contact, isKept: keptIDs.contains(contact.id))
                    }
                }
            }
        }
    }

    /// Bestätigung als Feld in der Liste statt als Pop-up: Der Nutzer sieht
    /// dabei weiter, welche Kontakte er behält.
    private var confirmationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(confirmationMessage)
                    .font(.callout)

                if !store.syncedSources.isEmpty {
                    Label(syncWarning, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 12) {
                    Button("Sichern und leeren", role: .destructive) {
                        let kept = keptIDs
                        let unlocked = purchases.isPurchased
                        withAnimation { showConfirmation = false }
                        Task { await store.swap(keeping: kept, isUnlocked: unlocked) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button("Abbrechen") {
                        withAnimation { showConfirmation = false }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("Adressbuch leeren?")
                .foregroundStyle(.red)
        }
        .listRowBackground(Color.red.opacity(0.07))
    }

    /// Die ausgewählten Kontakte – bewusst ungefiltert, damit die Suche in der
    /// unteren Liste die eigene Auswahl nicht aus dem Blick nimmt.
    private var keptContacts: [Contact] {
        store.deviceContacts.filter { keptIDs.contains($0.id) }
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

        if keptIDs.isEmpty {
            return "Alle \(store.deviceContacts.count) Kontakte werden entfernt. Ein Backup wird vorher automatisch angelegt – nichts geht verloren."
        }
        return "\(remove) Kontakte werden entfernt, \(keptIDs.count) bleiben. Ein Backup wird vorher automatisch angelegt."
    }

    /// Ohne diesen Zusatz wirkt der Swap wie eine rein lokale Aktion –
    /// bei aktiven Server-Quellen ist er das ausdrücklich nicht.
    private var syncWarning: String {
        let names = store.syncedSources.map(\.name).joined(separator: ", ")
        return "\(names) hängt an einem Server. Die Löschung wirkt dort und auf allen verbundenen Geräten."
    }

    private func toggle(_ id: String) {
        if keptIDs.contains(id) {
            keptIDs.remove(id)
        } else {
            keptIDs.insert(id)
        }
    }
}

struct ContactRow: View {
    let contact: Contact
    let isKept: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isKept ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isKept ? Color.accentColor : Color.secondary)

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

/// Sagt vor dem Swap, wie viel die kostenlose Fassung noch hergibt – und nach
/// dem letzten Swap, was zu tun ist.
struct FreeVersionRow: View {
    let remaining: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: remaining > 0 ? "gift.fill" : "lock.fill")
                .font(.title3)
                .foregroundStyle(remaining > 0 ? .blue : .secondary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(remaining > 0 ? "Kostenlose Fassung" : "Swap freischalten")
                    .font(.subheadline.bold())
                Text(remaining > 0
                     ? "Ein Swap ist enthalten. Danach lässt sich die App unter „Einstellungen“ dauerhaft freischalten."
                     : "Der enthaltene Swap ist aufgebraucht. Unter „Einstellungen“ dauerhaft freischalten – Wiederherstellen und Export bleiben kostenlos.")
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
