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
        if keptIDs.isEmpty {
            return "Alle \(store.deviceContacts.count) Kontakte werden entfernt. Ein Backup wird vorher automatisch angelegt – nichts geht verloren."
        }
        return "\(remove) Kontakte werden entfernt, \(keptIDs.count) bleiben. Ein Backup wird vorher automatisch angelegt."
    }

    private func toggle(_ id: String) {
        if keptIDs.contains(id) {
            keptIDs.remove(id)
        } else {
            keptIDs.insert(id)
        }
    }
}
