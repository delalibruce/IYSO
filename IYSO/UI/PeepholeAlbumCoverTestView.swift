import SwiftUI

private struct PeepholeSamplePhoto: Identifiable {
    let id: String
    let assetName: String
    let label: String
}

struct PeepholeAlbumCoverTestView: View {
    /// Same tokens as production gallery; flip to experiment in this sandbox only.
    private let palette: PeepholeVisualPalette = .gallery

    /// Which sample shows new/unviewed glow + "new!" badge — change to "1"…"4" to compare states.
    private let newPreviewSampleID = "1"

    /// Bundled sample photos for peephole tuning — replace asset names here to swap test images.
    private let samplePhotos: [PeepholeSamplePhoto] = [
        PeepholeSamplePhoto(id: "1", assetName: "PeepholeSample1", label: "IMG_3581"),
        PeepholeSamplePhoto(id: "2", assetName: "PeepholeSample2", label: "IMG_3582"),
        PeepholeSamplePhoto(id: "3", assetName: "PeepholeSample3", label: "IMG_3580"),
        PeepholeSamplePhoto(id: "4", assetName: "PeepholeSample4", label: "IMG_3579"),
    ]

    private let coverDiameter: CGFloat = 165
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            palette.sceneBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Peephole Cover Test")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(Color(white: 0xc8 / 255))
                    .tracking(-1.2)
                    .padding(.top, 16)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(Array(samplePhotos.enumerated()), id: \.element.id) { index, sample in
                        sampleCell(sample: sample, index: index)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func sampleCell(sample: PeepholeSamplePhoto, index: Int) -> some View {
        let isNew = sample.id == newPreviewSampleID

        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                if let image = UIImage(named: sample.assetName) {
                    PeepholeAlbumCover(
                        imageSource: .uiImage(image, cacheKey: sample.assetName),
                        size: coverDiameter,
                        isNew: isNew,
                        palette: palette
                    )
                } else {
                    missingAssetPlaceholder
                }

                if isNew {
                    newBadge
                }
            }
            .frame(width: coverDiameter, height: coverDiameter)

            Text("Sample \(index + 1)")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(white: 0xc8 / 255))
                .tracking(-0.4)

            Text(sample.label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(white: 0xc8 / 255).opacity(0.55))
                .tracking(-0.4)
        }
    }

    private var newBadge: some View {
        Text("new!")
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(Color(red: 0x12 / 255, green: 0x0c / 255, blue: 0x0a / 255))
            .tracking(-0.4)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 50)
                    .fill(Color(red: 0x4a / 255, green: 0x3a / 255, blue: 0x30 / 255))
            )
            .offset(x: -4, y: -4)
            .allowsHitTesting(false)
    }

    private var missingAssetPlaceholder: some View {
        ZStack {
            Circle()
                .fill(palette.housingRimColor)
                .frame(width: coverDiameter, height: coverDiameter)
            Circle()
                .fill(Color(white: 0.12))
                .frame(width: coverDiameter - 12, height: coverDiameter - 12)
        }
    }
}
