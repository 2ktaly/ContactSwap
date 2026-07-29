import SwiftUI
import Contacts

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var purchases: PurchaseStore

    @State private var showingSyncGuide = false
    @State private var showingDisguiseGuide = false
    @State private var selectedIcon = AppIconOption.all[0]

    var body: some View {
        NavigationStack {
            List {
                purchaseSection
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

    // MARK: - Kauf

    @ViewBuilder
    private var purchaseSection: some View {
        if purchases.isPurchased {
            Section {
                Label("Freigeschaltet", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } header: {
                Text("Fassung")
            } footer: {
                Text("Unbegrenzte Swaps, dauerhaft. Der Kauf gilt für alle Geräte mit derselben Apple-ID.")
            }
        } else {
            Section {
                LabeledContent("Swaps übrig", value: "\(store.remainingFreeSwaps) von \(SwapAllowance.freeLimit)")

                Button {
                    buy()
                } label: {
                    HStack {
                        Label("Dauerhaft freischalten", systemImage: "lock.open.fill")
                        Spacer()
                        Text(purchases.priceText)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(purchases.isLoading)
                .accessibilityIdentifier("buy-lifetime")

                Button("Kauf wiederherstellen") {
                    restore()
                }
                .disabled(purchases.isLoading)
                .accessibilityIdentifier("restore-purchase")
            } header: {
                Text("Fassung")
            } footer: {
                Text("Einmalig, kein Abonnement. Wiederherstellen, Export und Prüfen bleiben auch ohne Kauf unbegrenzt. Begrenzt ist nur das Leeren des Adressbuchs.")
            }

            Section {
                Link(destination: Self.bulkLicenseURL) {
                    Label("Massenlizenzen für Behörden", systemImage: "building.columns")
                }
                .accessibilityIdentifier("bulk-licenses")
            } footer: {
                Text("Behörden und Institutionen beziehen Lizenzen im Bündel über Apple Business Manager. Auf der Website stehen der Ablauf und die Ansprechpartner.")
            }
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
                 : "Orange markierte Quellen hängen an einem Server. Löschungen wirken dort und auf allen verbundenen Geräten. Manche Dienste spielen Kontakte auch wieder zurück.")
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
            Text("Das Icon lässt sich hier wechseln. Den Namen darunter kann iOS nicht zur Laufzeit ändern. Dafür gibt es den Weg über einen Kurzbefehl.")
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
                openAppSettings()
            } label: {
                HStack {
                    Label("Kontaktfreigabe in den Systemeinstellungen",
                          systemImage: store.hasAccess ? "gear" : "exclamationmark.triangle.fill")
                        .foregroundStyle(store.hasAccess ? Color.accentColor : .orange)
                    Spacer()
                    Text(permissionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("open-app-settings")
        } header: {
            Text("Kontakte")
        } footer: {
            Text(store.hasAccess
                 ? "Führt direkt zu dieser App in den Systemeinstellungen, etwa wenn die Kontaktfreigabe versehentlich entzogen wurde."
                 : "Ohne Kontaktfreigabe kann die App weder sichern noch wiederherstellen. Der Knopf führt direkt zur richtigen Stelle in den Systemeinstellungen.")
        }
    }

    private func openAppSettings() {
        // Führt in den Systemeinstellungen direkt zu dieser App, nicht nur
        // zur Startseite – dort steht auch der Schalter für die Kontakte.
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            LabeledContent("Kontakte im Adressbuch", value: "\(store.deviceContacts.count)")
            LabeledContent("Backups", value: "\(store.backups.count)")
            LabeledContent("Speicherung", value: "lokal, verschlüsselt")
            LabeledContent("Version", value: Bundle.main.shortVersion)
        } header: {
            Text("Status")
        } footer: {
            Text("Backups liegen AES-verschlüsselt auf dem Gerät. Der Schlüssel steckt im Schlüsselbund dieses iPhones und verlässt es nicht, auch nicht über ein iCloud-Backup. Ein Passwort brauchst du nicht, der Gerätecode schützt ihn.")
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
            Text("Der vollständige Quelltext ist für jeden einsehbar, auch ohne Kauf. Einsehbar heißt nicht frei verwendbar: Vervielfältigung und Weitergabe sind laut Lizenz untersagt.")
        }
    }

    static let repositoryURL = URL(string: "https://github.com/2ktaly/ContactSwap")!
    static let bulkLicenseURL = URL(string: "https://websitewerker.com/conswa/behoerden")!

    // MARK: - Kaufvorgang

    private func buy() {
        Task {
            switch await purchases.purchase() {
            case .purchased:
                store.alert = .info("Freigeschaltet", "Ab jetzt sind Swaps unbegrenzt möglich.")
            case .pending:
                store.alert = .info("Kauf angefragt", "Der Kauf muss noch bestätigt werden. Die Freischaltung erfolgt danach von selbst.")
            case .cancelled:
                break
            case .failed(let reason):
                store.alert = .info("Kauf nicht abgeschlossen", "\(reason)")
            }
        }
    }

    private func restore() {
        Task {
            let restored = await purchases.restore()
            store.alert = restored
                ? .info("Kauf gefunden", "Die App ist freigeschaltet.")
                : .info("Kein Kauf gefunden", "Unter dieser Apple-ID liegt kein Kauf vor.")
        }
    }

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
