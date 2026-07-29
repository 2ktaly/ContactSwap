import SwiftUI
import Contacts

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

                Section("Status") {
                    LabeledContent("Kontakte im Adressbuch", value: "\(store.deviceContacts.count)")
                    LabeledContent("Backups", value: "\(store.backups.count)")
                    LabeledContent("Kontaktfreigabe", value: permissionLabel)
                    LabeledContent("Speicherung", value: "lokal, unverschlüsselt")
                    LabeledContent("Version", value: Bundle.main.shortVersion)
                }

                Section {
                    Text("Kontakte werden nie endgültig gelöscht: Vor jedem Leeren legt die App automatisch ein vollständiges Backup an.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
            .refreshable { await store.reloadAll() }
            .sheet(isPresented: $showingGoogleGuide) {
                GoogleSyncGuideView()
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
