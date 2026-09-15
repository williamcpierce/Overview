/* Core/SavedPreview.swift — Versioned layout storage, source groups, and safe display restoration. */
import CoreGraphics
import Foundation

struct Window: Codable, Equatable, Identifiable {
    var id: UUID
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    /// Ordered source group assigned to this preview slot.
    var sources: [SourceIdentity]
    /// When true, this preview shows an inactive group member (or hides if none remain).
    var hideWhenFocused: Bool
    var displayIdentifier: String?

    var frame: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    /// First assigned identity; kept for call sites that still speak in singular terms.
    var source: SourceIdentity? { sources.first }

    init(
        frame: CGRect,
        id: UUID = UUID(),
        sources: [SourceIdentity] = [],
        hideWhenFocused: Bool = false,
        displayIdentifier: String? = nil,
        source: SourceIdentity? = nil
    ) {
        self.id = id
        x = frame.origin.x
        y = frame.origin.y
        width = frame.width
        height = frame.height
        if !sources.isEmpty {
            self.sources = sources
        } else if let source {
            self.sources = [source]
        } else {
            self.sources = []
        }
        self.hideWhenFocused = hideWhenFocused
        self.displayIdentifier = displayIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case id, x, y, width, height, source, sources, hideWhenFocused, displayIdentifier
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        width = try c.decode(Double.self, forKey: .width)
        height = try c.decode(Double.self, forKey: .height)
        guard [x, y, width, height].allSatisfy(\.isFinite), width > 0, height > 0 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid preview geometry"))
        }
        if let group = try c.decodeIfPresent([SourceIdentity].self, forKey: .sources), !group.isEmpty {
            sources = group
        } else if let legacy = try c.decodeIfPresent(SourceIdentity.self, forKey: .source) {
            sources = [legacy]
        } else {
            sources = []
        }
        hideWhenFocused = try c.decodeIfPresent(Bool.self, forKey: .hideWhenFocused) ?? false
        displayIdentifier = try c.decodeIfPresent(String.self, forKey: .displayIdentifier)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(x, forKey: .x)
        try c.encode(y, forKey: .y)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode(sources, forKey: .sources)
        // Retain singular `source` so older readers of the same version still see an assignment.
        try c.encodeIfPresent(sources.first, forKey: .source)
        try c.encode(hideWhenFocused, forKey: .hideWhenFocused)
        try c.encodeIfPresent(displayIdentifier, forKey: .displayIdentifier)
    }
}

struct SavedCollection<Value: Codable>: Codable {
    let version: Int
    let items: [Value]
    init(_ items: [Value]) { version = 1; self.items = items }

    static func decode(_ data: Data) throws -> (items: [Value], legacy: Bool) {
        if let collection = try? JSONDecoder().decode(Self.self, from: data) {
            guard collection.version == 1 else { throw StorageError.unsupportedVersion }
            return (collection.items, false)
        }
        return (try JSONDecoder().decode([Value].self, from: data), true)
    }
    enum StorageError: Error { case unsupportedVersion }
}

enum PreviewGeometry {
    static func clamp(_ frame: CGRect, to visible: CGRect) -> CGRect {
        let width = min(max(100, frame.width), visible.width)
        let height = min(max(50, frame.height), visible.height)
        return CGRect(x: min(max(frame.minX, visible.minX), visible.maxX - width),
                      y: min(max(frame.minY, visible.minY), visible.maxY - height),
                      width: width, height: height)
    }

    static func captureSize(source: CGSize, scale: CGFloat, preview: CGSize) -> CGSize {
        let native = CGSize(width: max(1, source.width * scale), height: max(1, source.height * scale))
        guard preview.width > 0, preview.height > 0 else { return native }
        let ratio = min(1, max(preview.width / native.width, preview.height / native.height))
        return CGSize(width: max(1, ceil(native.width * ratio)), height: max(1, ceil(native.height * ratio)))
    }
}
