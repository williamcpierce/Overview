/* Capture/Services/CaptureConfigurationService.swift — Pixel-aware preview configuration. */
import ScreenCaptureKit

@MainActor
final class CaptureConfigurationService {
    func createConfiguration(_ source: SCWindow, frameRate: Double, pixelSize: CGSize = .zero)
        -> (SCStreamConfiguration, SCContentFilter) {
        let filter = SCContentFilter(desktopIndependentWindow: source)
        let config = SCStreamConfiguration()
        let size = PreviewGeometry.captureSize(source: filter.contentRect.size,
                                              scale: CGFloat(filter.pointPixelScale), preview: pixelSize)
        config.width = Int(size.width)
        config.height = Int(size.height)
        config.minimumFrameInterval = CMTime(seconds: 1 / max(1, min(120, frameRate.isFinite ? frameRate : 15)), preferredTimescale: 60_000)
        config.queueDepth = 3
        config.showsCursor = false
        config.capturesAudio = false
        config.captureMicrophone = false
        config.captureDynamicRange = .SDR
        return (config, filter)
    }
}
