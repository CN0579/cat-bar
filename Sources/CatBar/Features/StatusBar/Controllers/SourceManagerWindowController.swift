import AppKit
import SwiftUI

private struct SourceManagerWindowRootView: View {
    @ObservedObject var appSession: AppSession
    let closeWindow: () -> Void

    var body: some View {
        RemoteMachineManagerView(
            store: self.appSession.remoteMachineStore,
            localControllerDisplay: self.appSession.localExternalControllerDisplay,
            onSwitchTarget: { target in
                Task { @MainActor in
                    await self.appSession.switchToMachineTarget(target)
                }
            },
            onClose: self.closeWindow)
    }
}

@MainActor
final class SourceManagerWindowController: NSWindowController, NSWindowDelegate {
    private let appSession: AppSession
    private var hostingController: NSHostingController<SourceManagerWindowRootView>?

    init(appSession: AppSession) {
        self.appSession = appSession

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 436, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbar = nil
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.level = .statusBar
        window.collectionBehavior = [.moveToActiveSpace]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.minSize = NSSize(width: 436, height: 500)
        window.maxSize = NSSize(width: 436, height: 700)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: window)

        window.delegate = self
        self.rebuildContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func present(preferredScreen: NSScreen? = nil) {
        self.rebuildContent()
        self.centerWindowOnActiveScreen(preferredScreen: preferredScreen)
        NSApp.activate(ignoringOtherApps: true)
        self.showWindow(nil)
        self.window?.makeKeyAndOrderFront(nil)
        self.centerWindowOnActiveScreen(preferredScreen: preferredScreen)
        DispatchQueue.main.async { [weak self] in
            self?.centerWindowOnActiveScreen(preferredScreen: preferredScreen)
        }
    }

    func closeRequested() {
        self.close()
    }

    func windowWillClose(_ notification: Notification) {
        self.window?.contentViewController = nil
        self.hostingController = nil
    }

    private func rebuildContent() {
        let rootView = SourceManagerWindowRootView(
            appSession: self.appSession,
            closeWindow: { [weak self] in
                self?.closeRequested()
            })

        if let hostingController {
            hostingController.rootView = rootView
            self.window?.contentViewController = hostingController
        } else {
            let hostingController = NSHostingController(rootView: rootView)
            hostingController.sizingOptions = [.preferredContentSize]
            self.hostingController = hostingController
            self.window?.contentViewController = hostingController
        }
    }

    private func centerWindowOnActiveScreen(preferredScreen: NSScreen? = nil) {
        guard let window = self.window else { return }

        let targetScreen = self.activeScreen(for: window, preferredScreen: preferredScreen)
        let visibleFrame = targetScreen.visibleFrame
        let windowSize = window.frame.size
        let origin = CGPoint(
            x: visibleFrame.midX - (windowSize.width / 2),
            y: visibleFrame.midY - (windowSize.height / 2))

        window.setFrameOrigin(origin)
    }

    private func activeScreen(for window: NSWindow, preferredScreen: NSScreen? = nil) -> NSScreen {
        if let preferredScreen {
            return preferredScreen
        }

        if let keyWindowScreen = NSApp.keyWindow?.screen {
            return keyWindowScreen
        }

        if let mainWindowScreen = NSApp.mainWindow?.screen {
            return mainWindowScreen
        }

        if let currentScreen = window.screen {
            return currentScreen
        }

        if let mainScreen = NSScreen.main {
            return mainScreen
        }

        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return mouseScreen
        }

        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }
}
