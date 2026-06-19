import UIKit

enum HapticEngine {
    static func light()  { guard AppSettings.hapticsEnabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { guard AppSettings.hapticsEnabled else { return }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()  { guard AppSettings.hapticsEnabled else { return }; UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func error()  { guard AppSettings.hapticsEnabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func success(){ guard AppSettings.hapticsEnabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
