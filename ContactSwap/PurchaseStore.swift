import Foundation
import Combine
import StoreKit

/// Verwaltet den einmaligen Kauf, der die App dauerhaft freischaltet.
///
/// Bewusst ausschließlich über In-App-Kauf: Freischaltcodes von einer eigenen
/// Website wären ein Verstoß gegen App-Store-Richtlinie 3.1.1, die eigene
/// Mechanismen wie Lizenzschlüssel oder QR-Codes ausdrücklich untersagt.
/// Behörden kaufen stattdessen Volumenlizenzen über Apple Business Manager.
@MainActor
final class PurchaseStore: ObservableObject {

    static let productID = "enricofrank.ContactSwap.lifetime"

    @Published private(set) var product: Product?
    @Published private(set) var isPurchased = false
    @Published private(set) var isLoading = false

    private var updates: Task<Void, Never>?

    init() {
        // Läuft die ganze Laufzeit mit, damit auch Käufe ankommen, die
        // außerhalb der App abgeschlossen wurden – etwa nach einer
        // Zahlungsfreigabe durch die Eltern oder einem Kauf am Mac.
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self.refreshEntitlement()
                }
            }
        }
    }

    deinit {
        updates?.cancel()
    }

    var priceText: String {
        product?.displayPrice ?? "3,99 €"
    }

    // MARK: - Laden

    func load() async {
        await refreshEntitlement()

        guard product == nil else { return }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            // Ohne Netz bleibt der Preis der Platzhalter – kein Grund,
            // den Nutzer mit einer Fehlermeldung zu behelligen.
            product = nil
        }
    }

    /// Fragt bei StoreKit nach, ob der Kauf vorliegt. `currentEntitlements`
    /// ist die verlässliche Quelle – sie enthält auch Käufe über Apple
    /// Business Manager und die Familienfreigabe.
    func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            isPurchased = true
            return
        }
        isPurchased = false
    }

    // MARK: - Kaufen

    enum PurchaseOutcome {
        case purchased
        case pending
        case cancelled
        case failed(String)
    }

    func purchase() async -> PurchaseOutcome {
        guard let product else {
            return .failed("Das Produkt konnte nicht geladen werden. Besteht eine Internetverbindung?")
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("Der Kauf ließ sich nicht überprüfen.")
                }
                await transaction.finish()
                await refreshEntitlement()
                return .purchased

            case .pending:
                // Etwa bei „Kauf anfragen“ – die Freischaltung kommt später
                // über Transaction.updates an.
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                return .failed("Unbekannte Antwort des App Store.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        // Ausdrücklich qualifiziert: Die App hat eine eigene Klasse AppStore,
        // die den Typ aus StoreKit sonst verdeckt.
        try? await StoreKit.AppStore.sync()
        await refreshEntitlement()
        return isPurchased
    }
}
