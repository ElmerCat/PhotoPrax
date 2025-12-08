//  Prax-1207-0
//
//  AssetDetailView.swift
//  PhotoPrax
//
import SwiftUI
@preconcurrency import Photos

struct AssetDetailView: View {
    let asset: PHAsset?

    var body: some View {
        if let asset {
            VStack(spacing: 20) {
                PhotoThumbnailView(asset: asset, size: 250)
                    .id(asset.localIdentifier)
                    .cornerRadius(12)
                if let date = asset.creationDate {
                    Text("Taken on \(date.formatted(date: .long, time: .shortened))")
                }
            }
        } else {
            Text("Select a photo")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    AssetDetailView(asset: nil)
}
