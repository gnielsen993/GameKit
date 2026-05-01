import Foundation

/// App-wide branding constants surfaced in Settings → About and the support flow.
enum AppInfo {
    static let displayName = "GameDrawer"
    static let shortName = "GameDrawer"
    static let supportEmail = "support@lauterstar.com"
    static let termsURL = URL(string: "https://gamedrawer.lauterstar.com/terms.html")!
    static let privacyURL = URL(string: "https://gamedrawer.lauterstar.com/privacy.html")!
    static let supportSubject = "GameDrawer support"

    static var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(v) (\(b))"
    }
}
