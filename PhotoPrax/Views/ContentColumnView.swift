//  Prax-1207-0
//
//  ContentColumnView.swift
//  PhotoPrax
//
import SwiftUI
@preconcurrency import Photos

struct ContentColumnView: View {
    let items: Set<SidebarItem>
    @Binding var selectedAssetIDs: Set<String>
    @EnvironmentObject var viewModel: PhotoLibraryViewModel
    
    @State private var resetID: String? = nil
    
    var body: some View {
        Group {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Text("No selection")
                        .foregroundStyle(.secondary)
                    Text("Select \"All Photos\" or one or more albums from the sidebar.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            } else {
                AssetsListView(
                    assets: viewModel.assets,
                    isLoading: viewModel.isLoadingAssets,
                    resetID: resetID,
                    selectedAssetIDs: $selectedAssetIDs
                )
            }
        }
        .onAppear {
            resetID = computeResetID(for: items)
            viewModel.loadAssets(for: items)
        }
        .onChange(of: items) { _, newSelection in
            resetID = computeResetID(for: newSelection)
            selectedAssetIDs.removeAll()
            viewModel.loadAssets(for: newSelection)
        }
        .navigationTitle(navigationTitle(for: items))
    }
    
    private func navigationTitle(for items: Set<SidebarItem>) -> String {
        if items.isEmpty { return "Photos" }
        if items.contains(.allPhotos) { return "All Photos" }
        if items.count == 1, let first = items.first {
            switch first {
            case .allPhotos: return "All Photos"
            case .noAlbums: return "Not In Any Album"
            case .album(let id):
                if let album = viewModel.userAlbums.first(where: { $0.localIdentifier == id })
                    ?? viewModel.smartAlbums.first(where: { $0.localIdentifier == id }) {
                    return album.localizedTitle ?? "Untitled"
                }
                return "Album"
            }
        }
        return "Selection"
    }
    
    private func computeResetID(for items: Set<SidebarItem>) -> String {
        items.map { $0.resetID }.sorted().joined(separator: "|")
    }
}

#Preview {
    ContentColumnView(items: [.allPhotos], selectedAssetIDs: .constant([]))
        .environmentObject(PhotoLibraryViewModel())
}
