import SwiftUI

/// Erklärt vor der Systemabfrage, wozu der Kontaktzugriff gebraucht wird.
///
/// Der iOS-Dialog erlaubt nur einen Satz und lässt sich nicht wiederholen:
/// Wer dort ablehnt, muss den Weg über die Systemeinstellungen gehen. Deshalb
/// kommt die Erklärung davor, nicht danach.
struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    PromiseRow(
                        symbol: "person.2.fill",
                        tint: .blue,
                        title: "Kontaktzugriff wird benötigt",
                        text: "Ohne Freigabe kann die App dein Adressbuch weder sichern noch zurückschreiben. Im nächsten Schritt fragt iOS danach."
                    )

                    PromiseRow(
                        symbol: "lock.iphone",
                        tint: .green,
                        title: "Ausschließlich auf diesem Gerät",
                        text: "Alle Kontakte werden lokal verarbeitet und verschlüsselt auf dem iPhone gesichert. Die App sendet nichts ins Netz – es gibt kein Konto, keinen Server, keine Auswertung."
                    )

                    PromiseRow(
                        symbol: "arrow.uturn.backward.circle.fill",
                        tint: .orange,
                        title: "Nichts geht verloren",
                        text: "Vor jedem Leeren legt die App automatisch ein vollständiges Backup an. Unter „Zurück“ lässt es sich jederzeit wieder einspielen."
                    )

                    PromiseRow(
                        symbol: "curlybraces",
                        tint: .purple,
                        title: "Nachprüfbar",
                        text: "Der Quelltext ist offengelegt. Wer will, kann selbst nachlesen, dass keine Daten das Gerät verlassen."
                    )
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }

            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.blue)
                .padding(.top, 44)

            Text("Willkommen")
                .font(.largeTitle.bold())

            Text("Diese App räumt dein Adressbuch vorübergehend leer und holt es vollständig zurück.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: onContinue) {
                Text("Weiter")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Im nächsten Schritt fragt iOS nach dem Kontaktzugriff.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(.bar)
    }
}

private struct PromiseRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
