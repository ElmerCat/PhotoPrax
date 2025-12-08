//  Prax-1207-0
//
//  ContentView.swift
//  PhotoPrax
//
//  Created by Elmer Cat on 9/27/25.
//

import SwiftUI
@preconcurrency import Photos
import Combine

import AppKit

@MainActor fileprivate func loadAssets(for selection: Set<SidebarItem>) {
    // Placeholder if needed elsewhere
}

struct ContentView: View {
    @EnvironmentObject var viewModel: PhotoLibraryViewModel
    @State private var selectedItems: Set<SidebarItem> = []
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @SceneStorage("SidebarSelection") private var storedSidebarSelection: String?
    @SceneStorage("SceneID") private var sceneID: String = UUID().uuidString
    @SceneStorage("MyAlbumsExpanded") private var isMyAlbumsExpanded: Bool = true
    @SceneStorage("SmartAlbumsExpanded") private var isSmartAlbumsExpanded: Bool = true
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var activityNonce: Int = 0
    @State private var selectedAssetIDs: Set<String> = []

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            AlbumsSidebarView(
                selectedItems: $selectedItems,
                isMyAlbumsExpanded: $isMyAlbumsExpanded,
                isSmartAlbumsExpanded: $isSmartAlbumsExpanded
            )
          /*  .toolbar {
                if columnVisibility == .all {
                    ToolbarItem {
                        Button {
                            viewModel.refreshAlbumCounts()
                        } label: {
                            Label("Refresh Counts", systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoadingAlbumCounts)
                        .help("Recompute album photo counts")
                    }
                }
            }*/
        } content: {
            ContentColumnView(
                items: selectedItems,
                selectedAssetIDs: $selectedAssetIDs
            )
        } detail: {
            Group {
                let assetsByID = Dictionary(uniqueKeysWithValues: viewModel.assets.map { ($0.localIdentifier, $0) })
                let selectedAssets: [PHAsset] = selectedAssetIDs.compactMap { assetsByID[$0] }
                if selectedAssets.isEmpty {
                    Text("Select a photo")
                        .foregroundStyle(.secondary)
                } else if selectedAssets.count == 1 {
                    AssetDetailView(asset: selectedAssets.first)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(selectedAssets.count) items selected")
                            .font(.headline)
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(90), spacing: 8), count: 4), spacing: 8) {
                                ForEach(selectedAssets, id: \.localIdentifier) { asset in
                                    PhotoThumbnailView(asset: asset, size: 90)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                }
            }
        }
        .onChange(of: selectedItems) { _, newValue in
            storedSidebarSelection = encode(newValue)
            activityNonce &+= 1
        }
        .onChange(of: storedSidebarSelection) { _, newValue in
            if let decoded = decode(newValue), decoded != selectedItems {
                selectedItems = decoded
            }
        }
        .onChange(of: isMyAlbumsExpanded) { _, _ in activityNonce &+= 1 }
        .onChange(of: isSmartAlbumsExpanded) { _, _ in activityNonce &+= 1 }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active, .inactive, .background:
                activityNonce &+= 1
            @unknown default:
                activityNonce &+= 1
            }
        }
        .onContinueUserActivity("com.elmercat.PhotoPrax.scene") { activity in
            if let selectionString = activity.userInfo?["selection"] as? String {
                storedSidebarSelection = selectionString
                if let decoded = decode(selectionString) {
                    selectedItems = decoded
                }
            }
            if let my = activity.userInfo?["myExpanded"] as? Bool {
                isMyAlbumsExpanded = my
            }
            if let smart = activity.userInfo?["smartExpanded"] as? Bool {
                isSmartAlbumsExpanded = smart
            }
        }
        .onAppear {
            if sceneID.isEmpty { sceneID = UUID().uuidString }
            // Avoid clobbering restored state: only apply a default if there's no stored selection
            if selectedItems.isEmpty {
                if let stored = storedSidebarSelection, let decoded = decode(stored) {
                    selectedItems = decoded
                } else {
                    // Defer the default to allow SceneStorage restoration to materialize first
                    DispatchQueue.main.async {
                        if selectedItems.isEmpty { selectedItems = [.allPhotos] }
                    }
                }
            }
        }
        .userActivity("com.elmercat.PhotoPrax.scene") { activity in
            _ = activityNonce
            activity.persistentIdentifier = sceneID
            activity.title = "PhotoPrax Window"
            var info: [String: Any] = [:]
            info["selection"] = encode(selectedItems)
            info["myExpanded"] = isMyAlbumsExpanded
            info["smartExpanded"] = isSmartAlbumsExpanded
            activity.addUserInfoEntries(from: info)
        }
    }

    private func encode(_ items: Set<SidebarItem>) -> String? {
        if items.isEmpty { return nil }
        let parts = items.map { item -> String in
            switch item {
            case .allPhotos: return "all"
            case .noAlbums: return "none"
            case .album(let id): return "album:\(id)"
            }
        }.sorted()
        return parts.joined(separator: ",")
    }

    private func decode(_ s: String?) -> Set<SidebarItem>? {
        guard let s = s, !s.isEmpty else { return nil }
        var result: Set<SidebarItem> = []
        for part in s.split(separator: ",") {
            if part == "all" {
                result.insert(.allPhotos)
            } else if part == "none" {
                result.insert(.noAlbums)
            } else if part.hasPrefix("album:") {
                let id = String(part.dropFirst("album:".count))
                result.insert(.album(id))
            }
        }
        if result.isEmpty { return nil }
        // Enforce exclusivity if both 'all' and others are present
        if result.contains(.allPhotos) && result.count > 1 {
            return [.allPhotos]
        }
        return result
    }

    private func toggleSidebarMac() {
        NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
    }
}


#Preview {
    Text("Preview not available for Photos library")
}

