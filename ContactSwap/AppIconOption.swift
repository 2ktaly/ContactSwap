import Foundation
import UIKit

/// Ein wählbares App-Icon.
///
/// iOS erlaubt nur Icons, die beim Bauen mitgeliefert wurden – ein beliebiges
/// Foto als Icon ist nicht möglich. Neue Motive kommen über `Tools/makeicons.py`
/// dazu und müssen zusätzlich in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`
/// eingetragen werden.
struct AppIconOption: Identifiable, Sendable {
    /// Der Name im Asset-Katalog. `nil` steht für das Standard-Icon.
    let name: String?
    let title: String
    let previewAsset: String

    var id: String { name ?? "default" }

    static let all: [AppIconOption] = [
        AppIconOption(name: nil, title: "ContactSwap", previewAsset: "AppIconPreview"),
        AppIconOption(name: "IconCalculator", title: "Rechner", previewAsset: "IconCalculatorPreview"),
        AppIconOption(name: "IconNotes", title: "Notizen", previewAsset: "IconNotesPreview"),
        AppIconOption(name: "IconCompass", title: "Kompass", previewAsset: "IconCompassPreview"),
        AppIconOption(name: "IconClock", title: "Uhr", previewAsset: "IconClockPreview")
    ]
}

@MainActor
enum AppIconManager {

    static var isSupported: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    static var current: AppIconOption {
        let active = UIApplication.shared.alternateIconName
        return AppIconOption.all.first { $0.name == active } ?? AppIconOption.all[0]
    }

    /// Wechselt das Icon.
    ///
    /// iOS zeigt dabei eine eigene Meldung „Du hast das Symbol geändert“ – die
    /// lässt sich nicht unterdrücken, sie erscheint aber nur im Moment des
    /// Wechsels und nicht später.
    static func apply(_ option: AppIconOption) async throws {
        guard isSupported, UIApplication.shared.alternateIconName != option.name else { return }
        try await UIApplication.shared.setAlternateIconName(option.name)
    }
}
