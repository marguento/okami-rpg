import Foundation

enum AppSettings {
    private static let defaults = UserDefaults.standard

    static var sfxMuted: Bool {
        get { defaults.bool(forKey: "sfxMuted") }
        set { defaults.set(newValue, forKey: "sfxMuted") }
    }

    static var hapticsEnabled: Bool {
        get { defaults.object(forKey: "hapticsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "hapticsEnabled") }
    }

    static var showFPS: Bool {
        get { defaults.bool(forKey: "showFPS") }
        set { defaults.set(newValue, forKey: "showFPS") }
    }

    static var musicMuted: Bool {
        get { defaults.bool(forKey: "musicMuted") }
        set { defaults.set(newValue, forKey: "musicMuted") }
    }
}
