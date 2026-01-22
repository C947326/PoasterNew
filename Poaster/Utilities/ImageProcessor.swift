//
//  ImageProcessor.swift
//  Poaster
//

import Foundation
import AppKit
import CoreGraphics

/// Result of image processing
struct ProcessedImage {
    let imageData: Data
    let thumbnailData: Data
}

/// Utility for processing images for upload and display
enum ImageProcessor {

    /// Process raw image data into optimized formats for storage
    /// - Parameter data: Raw image data (JPEG, PNG, etc.)
    /// - Returns: Processed image with full-size and thumbnail data, or nil if processing fails
    static func process(_ data: Data) -> ProcessedImage? {
        guard let image = NSImage(data: data) else { return nil }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        // Resize if needed
        let resized = resizeIfNeeded(cgImage)

        // Create thumbnail
        guard let thumbnail = createThumbnail(cgImage) else { return nil }

        // Convert to JPEG data
        guard let imageData = jpegData(from: resized, quality: 0.85) else { return nil }
        guard let thumbnailData = jpegData(from: thumbnail, quality: 0.7) else { return nil }

        return ProcessedImage(imageData: imageData, thumbnailData: thumbnailData)
    }

    /// Resize the image if it exceeds maximum dimensions
    private static func resizeIfNeeded(_ image: CGImage) -> CGImage {
        let maxDimension = Constants.Images.maxDimension
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        // Check if resize is needed
        if width <= maxDimension && height <= maxDimension {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let scale: CGFloat
        if width > height {
            scale = maxDimension / width
        } else {
            scale = maxDimension / height
        }

        let newWidth = Int(width * scale)
        let newHeight = Int(height * scale)

        return resize(image, to: CGSize(width: newWidth, height: newHeight)) ?? image
    }

    /// Create a thumbnail from the image
    private static func createThumbnail(_ image: CGImage) -> CGImage? {
        let size = Constants.Images.thumbnailSize

        // Calculate the crop rect for a square thumbnail
        let originalWidth = CGFloat(image.width)
        let originalHeight = CGFloat(image.height)
        let cropSize = min(originalWidth, originalHeight)
        let cropX = (originalWidth - cropSize) / 2
        let cropY = (originalHeight - cropSize) / 2
        let cropRect = CGRect(x: cropX, y: cropY, width: cropSize, height: cropSize)

        // Crop to square
        guard let cropped = image.cropping(to: cropRect) else { return nil }

        // Resize to thumbnail size
        return resize(cropped, to: size)
    }

    /// Resize a CGImage to the specified size
    private static func resize(_ image: CGImage, to size: CGSize) -> CGImage? {
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(origin: .zero, size: size))

        return context?.makeImage()
    }

    /// Convert a CGImage to JPEG data
    private static func jpegData(from image: CGImage, quality: CGFloat) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        return bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: quality]
        )
    }

    /// Check if the image data is within the size limit
    static func isWithinSizeLimit(_ data: Data) -> Bool {
        data.count <= Constants.Images.maxFileSize
    }

    /// Get the dimensions of image data
    static func dimensions(of data: Data) -> CGSize? {
        guard let image = NSImage(data: data) else { return nil }
        return image.size
    }
}
