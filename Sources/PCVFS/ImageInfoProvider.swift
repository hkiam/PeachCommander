// SPDX-License-Identifier: Apache-2.0
// ImageInfoProvider.swift - Built-in "content" fields for images (SPEC-012 §5, I16-T04).
//
// Reads image metadata (pixel dimensions, colour model, DPI) via ImageIO without
// decoding the full bitmap, cheaply enough to feed custom columns / search /
// multi-rename. This is the built-in analogue of a WDX content plugin.

import Foundation
import ImageIO

public struct ImageInfo: Equatable, Sendable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let colorModel: String?   // "RGB", "Gray", "CMYK", …
    public let dpi: Int?

    public init(pixelWidth: Int, pixelHeight: Int, colorModel: String? = nil, dpi: Int? = nil) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.colorModel = colorModel
        self.dpi = dpi
    }

    /// "1920 × 1080" for display in a column or dialog.
    public var dimensionsText: String { "\(pixelWidth) × \(pixelHeight)" }
}

public enum ImageInfoProvider {
    /// Read image info for a local file, or nil if it is not a decodable image.
    public static func info(at url: URL) -> ImageInfo? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        let colorModel = (props[kCGImagePropertyColorModel] as? String)
        let dpi = (props[kCGImagePropertyDPIWidth] as? NSNumber)?.intValue
        return ImageInfo(pixelWidth: width, pixelHeight: height, colorModel: colorModel, dpi: dpi)
    }
}
