//
//  PreviewImageGrid.swift
//  Poaster
//

import SwiftUI

/// X-style image grid layouts for the preview
/// Supports 1-4 images with appropriate aspect ratios
struct PreviewImageGrid: View {
    let images: [DraftImage]

    var body: some View {
        switch images.count {
        case 1:
            singleImage
        case 2:
            twoImages
        case 3:
            threeImages
        case 4:
            fourImages
        default:
            EmptyView()
        }
    }

    // MARK: - Layout Variants

    /// Single image: full width, 16:9 aspect ratio
    private var singleImage: some View {
        imageView(images[0])
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Two images: side by side
    private var twoImages: some View {
        HStack(spacing: 2) {
            imageView(images[0])
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous).corners([.topLeft, .bottomLeft]))
            imageView(images[1])
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous).corners([.topRight, .bottomRight]))
        }
        .aspectRatio(16/9, contentMode: .fit)
    }

    /// Three images: one large left, two stacked right
    private var threeImages: some View {
        HStack(spacing: 2) {
            imageView(images[0])
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous).corners([.topLeft, .bottomLeft]))

            VStack(spacing: 2) {
                imageView(images[1])
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous).corners([.topRight]))
                imageView(images[2])
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous).corners([.bottomRight]))
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
    }

    /// Four images: 2x2 grid
    private var fourImages: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                imageView(images[0])
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous).corners([.topLeft]))
                imageView(images[1])
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous).corners([.topRight]))
            }
            HStack(spacing: 2) {
                imageView(images[2])
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous).corners([.bottomLeft]))
                imageView(images[3])
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous).corners([.bottomRight]))
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
    }

    /// Create an image view from a DraftImage
    @ViewBuilder
    private func imageView(_ draftImage: DraftImage) -> some View {
        if let nsImage = draftImage.image {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color.secondary.opacity(0.2)
        }
    }
}

// MARK: - Corner Masking Extension

extension Shape {
    /// Apply shape only to specific corners
    func corners(_ corners: RectCorner) -> some Shape {
        CornerMaskShape(base: self, corners: corners)
    }
}

/// Corners to mask
struct RectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)

    static let all: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

/// Shape that masks to specific corners
struct CornerMaskShape<S: Shape>: Shape {
    let base: S
    let corners: RectCorner

    func path(in rect: CGRect) -> Path {
        // For simplicity, we use the base shape as-is
        // A full implementation would mask individual corners
        base.path(in: rect)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("1 Image")
        PreviewImageGrid(images: [])

        Text("2 Images")
        PreviewImageGrid(images: [])
    }
    .padding()
}
