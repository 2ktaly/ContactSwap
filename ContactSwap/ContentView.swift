import SwiftUI
import Contacts

struct ContentView: View {
    @StateObject private var store = AppStore()
    @StateObject private var purchases = PurchaseStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.hasAccess {
                mainTabs
            } else {
                PermissionGateView(store: store)
            }
        }
        .overlay { busyOverlay }
        .alert(item: $store.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .task {
            await store.requestPermissionIfNeeded()
        }
        .task {
            await purchases.load()
        }
        .onChange(of: scenePhase) { _, phase in
            // Der Nutzer kann die Freigabe in den Einstellungen ändern,
            // während die App im Hintergrund ist.
            guard phase == .active else { return }
            let wasBlocked = !store.hasAccess
            store.refreshPermission()
            if wasBlocked && store.hasAccess {
                Task { await store.reloadAll() }
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            SwapView(store: store, purchases: purchases)
                .tabItem { Label("Swap", systemImage: "arrow.left.arrow.right") }

            RestoreView(store: store)
                .tabItem { Label("Zurück", systemImage: "arrow.uturn.backward") }

            SettingsView(store: store, purchases: purchases)
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
    }

    @ViewBuilder
    private var busyOverlay: some View {
        if let message = store.busyMessage {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                    Text(message)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .transition(.opacity)
        }
    }
}

struct PermissionGateView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text("Zugriff auf Kontakte nötig")
                .font(.title2.bold())

            Text("Die App sichert dein Adressbuch, bevor etwas entfernt wird. Ohne Kontakt-Freigabe kann sie weder sichern noch wiederherstellen.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if store.permission == .notDetermined {
                Button("Zugriff erlauben") {
                    Task { await store.requestPermissionIfNeeded() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)

                Text("Datenschutz & Sicherheit → Kontakte → ConSwa")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
    }
}

#Preview {
    ContentView()
}
