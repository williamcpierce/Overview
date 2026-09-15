/* Capture/Capture.swift — Reuse the layer; retain only the latest surface. */
import SwiftUI

struct Capture: NSViewRepresentable {
    let frame: CapturedFrame
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.contentsGravity = .resizeAspect
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.layer?.contents = frame.surface
        view.layer?.contentsScale = view.window?.backingScaleFactor ?? 2
        CATransaction.commit()
    }
}

/// Backing-scale changes can happen without a SwiftUI size change when moving between displays.
struct PreviewSizeReader: NSViewRepresentable {
    let onSize: (CGSize) -> Void
    func makeNSView(context: Context) -> SizingView { SizingView(onSize: onSize) }
    func updateNSView(_ view: SizingView, context: Context) { view.onSize = onSize; view.report() }

    final class SizingView: NSView {
        var onSize: (CGSize) -> Void
        private var lastSize = CGSize.zero
        init(onSize: @escaping (CGSize) -> Void) { self.onSize = onSize; super.init(frame: .zero) }
        required init?(coder: NSCoder) { nil }
        override func layout() { super.layout(); report() }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); report() }
        override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); report() }
        func report() {
            let size = convertToBacking(bounds).size
            guard size.width > 0, size.height > 0, size != lastSize else { return }
            lastSize = size
            Task { @MainActor [weak self] in self?.onSize(size) }
        }
    }
}
