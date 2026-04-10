import SwiftUI

struct OpenSourceManagerWindowAction: @unchecked Sendable {
    let handler: () -> Void

    func callAsFunction() {
        self.handler()
    }
}

private struct OpenSourceManagerWindowKey: EnvironmentKey {
    static let defaultValue = OpenSourceManagerWindowAction(handler: {})
}

extension EnvironmentValues {
    var openSourceManagerWindow: OpenSourceManagerWindowAction {
        get { self[OpenSourceManagerWindowKey.self] }
        set { self[OpenSourceManagerWindowKey.self] = newValue }
    }
}
