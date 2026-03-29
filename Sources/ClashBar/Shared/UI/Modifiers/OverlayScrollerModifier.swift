import AppKit
import SwiftUI

// MARK: - Public API

/// A scroll container backed by a real NSScrollView where we have full
/// control over the scroller appearance. The native scroller is hidden; an
/// optional thin SwiftUI overlay knob can be enabled.
struct ThinScrollContainer<Content: View>: View {
    let height: CGFloat
    var showsOverlayKnob: Bool = false
    @ViewBuilder let content: Content

    @State private var scrollFraction: CGFloat = 0
    @State private var contentHeight: CGFloat = 1
    @State private var viewportHeight: CGFloat = 1
    @State private var indicatorOpacity: CGFloat = 0
    @State private var hideTask: Task<Void, Never>?

    private let knobWidth: CGFloat = 3
    private let knobMinHeight: CGFloat = 24
    private let knobTrailingInset: CGFloat = 2
    private let fadeDelay: TimeInterval = 1.2
    private let fadeDuration: TimeInterval = 0.3

    private var needsIndicator: Bool {
        contentHeight > viewportHeight + 1
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppKitScrollView(
                scrollFraction: $scrollFraction,
                contentHeight: $contentHeight,
                viewportHeight: $viewportHeight
            ) {
                content
            }
            .onChange(of: scrollFraction) { _ in
                guard self.showsOverlayKnob else { return }
                flashIndicator()
            }

            if self.showsOverlayKnob, self.needsIndicator {
                indicatorKnob
                    .opacity(indicatorOpacity)
                    .animation(.easeInOut(duration: fadeDuration), value: indicatorOpacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: height)
        .clipped()
    }

    private var indicatorKnob: some View {
        let visibleRatio = viewportHeight / max(contentHeight, 1)
        let knobH = max(knobMinHeight, viewportHeight * visibleRatio)
        let trackH = viewportHeight - knobH
        let yOffset = trackH * min(max(scrollFraction, 0), 1)

        return RoundedRectangle(cornerRadius: knobWidth / 2, style: .continuous)
            .fill(Color.primary.opacity(0.28))
            .frame(width: knobWidth, height: knobH)
            .padding(.trailing, knobTrailingInset)
            .offset(y: yOffset)
    }

    private func flashIndicator() {
        indicatorOpacity = 1
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(fadeDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            indicatorOpacity = 0
        }
    }
}

// MARK: - AppKit-backed ScrollView

/// Wraps SwiftUI content inside a real NSScrollView with the scroller
/// completely hidden (`hasVerticalScroller = false`).  Scroll-position
/// and content-height measurements are reported back through bindings.
private struct AppKitScrollView<Content: View>: NSViewRepresentable {
    @Binding var scrollFraction: CGFloat
    @Binding var contentHeight: CGFloat
    @Binding var viewportHeight: CGFloat
    @ViewBuilder let content: Content

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = .init()

        // Host the SwiftUI content.
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: documentView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
        ])

        scrollView.documentView = documentView

        // Observe scroll & resize.
        context.coordinator.observe(scrollView: scrollView) { fraction, cHeight, vHeight in
            DispatchQueue.main.async {
                self.scrollFraction = fraction
                self.contentHeight = cHeight
                self.viewportHeight = vHeight
            }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Update the hosted SwiftUI content.
        if let documentView = scrollView.documentView,
           let hostingView = documentView.subviews.first as? NSHostingView<Content>
        {
            hostingView.rootView = content
        }

        // Re-ensure scrollers stay hidden.
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
    }

    @MainActor
    final class Coordinator: NSObject {
        nonisolated(unsafe) var scrollObserver: NSObjectProtocol?
        nonisolated(unsafe) var frameObserver: NSObjectProtocol?

        func observe(
            scrollView: NSScrollView,
            onChange: @MainActor @escaping (_ fraction: CGFloat, _ contentHeight: CGFloat, _ viewportHeight: CGFloat) -> Void
        ) {
            let nc = NotificationCenter.default

            let update: @MainActor () -> Void = { [weak scrollView] in
                guard let scrollView, let documentView = scrollView.documentView else { return }
                let clipBounds = scrollView.contentView.bounds
                let docHeight = documentView.frame.height
                let vpHeight = clipBounds.height
                let maxScroll = max(1, docHeight - vpHeight)
                let fraction = clipBounds.origin.y / maxScroll
                onChange(fraction, docHeight, vpHeight)
            }

            scrollObserver = nc.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { _ in MainActor.assumeIsolated { update() } }

            scrollView.contentView.postsBoundsChangedNotifications = true

            frameObserver = nc.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: scrollView.documentView,
                queue: .main
            ) { _ in MainActor.assumeIsolated { update() } }

            scrollView.documentView?.postsFrameChangedNotifications = true

            // Initial report.
            update()
        }

        deinit {
            if let o = scrollObserver { NotificationCenter.default.removeObserver(o) }
            if let o = frameObserver { NotificationCenter.default.removeObserver(o) }
        }
    }
}

/// A flipped NSView so that content starts from the top (matching SwiftUI's
/// coordinate system) rather than the bottom.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
