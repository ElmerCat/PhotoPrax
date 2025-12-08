//  Prax-1207-0
//
//  AlbumsSidebarView.swift
//  PhotoPrax
//
import SwiftUI
@preconcurrency import Photos

struct AlbumsSidebarView: View {
    @EnvironmentObject var viewModel: PhotoLibraryViewModel
    @Binding var selectedItems: Set<SidebarItem>
    @Binding var isMyAlbumsExpanded: Bool
    @Binding var isSmartAlbumsExpanded: Bool
    @State private var lastSelectionAnchor: SidebarItem? = nil

    private var selectionBinding: Binding<Set<SidebarItem>> {
        Binding(
            get: { selectedItems },
            set: { newValue in
                var normalized = newValue
                if newValue.contains(.allPhotos) && newValue.count > 1 {
                    if selectedItems.contains(.allPhotos) {
                        normalized.remove(.allPhotos)
                    } else {
                        normalized = [.allPhotos]
                    }
                }
                selectedItems = normalized
            }
        )
    }

    private func selectSingle(_ item: SidebarItem) {
        selectedItems = [item]
        lastSelectionAnchor = item
    }

    private func toggleItem(_ item: SidebarItem) {
        if case .allPhotos = item {
            selectedItems = [.allPhotos]
            lastSelectionAnchor = item
            return
        }
        var new = selectedItems
        new.remove(.allPhotos)
        if new.contains(item) {
            new.remove(item)
        } else {
            new.insert(item)
        }
        selectedItems = new
        lastSelectionAnchor = item
    }

    private func selectRange(to item: SidebarItem) {
        guard let anchor = lastSelectionAnchor else {
            selectSingle(item)
            return
        }
        guard case let .album(idTo) = item else {
            selectSingle(item)
            return
        }
        func rangeSet(in collections: [PHAssetCollection]) -> Set<SidebarItem>? {
            guard case let .album(idAnchor) = anchor,
                  let i1 = collections.firstIndex(where: { $0.localIdentifier == idAnchor }),
                  let i2 = collections.firstIndex(where: { $0.localIdentifier == idTo }) else { return nil }
            let lo = Swift.min(i1, i2), hi = Swift.max(i1, i2)
            let items = collections[lo...hi].map { SidebarItem.album($0.localIdentifier) }
            return Set(items)
        }
        if let set = rangeSet(in: viewModel.userAlbums) ?? rangeSet(in: viewModel.smartAlbums) {
            var new = selectedItems
            new.remove(.allPhotos)
            selectedItems = new.union(set)
            lastSelectionAnchor = item
        } else {
            selectSingle(item)
        }
    }

    var body: some View {
        List(selection: selectionBinding) {
            Section("Library") {
                HStack {
                    Text("All Photos")
                    Spacer()
                    Text(verbatim: String(viewModel.allPhotosCount))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .tag(SidebarItem.allPhotos)
                .listRowBackground((selectedItems.contains(.allPhotos)) ? Color.accentColor.opacity(0.12) : Color.clear)
            }
            Section {
                DisclosureGroup(isExpanded: $isMyAlbumsExpanded) {
                    HStack {
                        Text("Not In Any Album")
                        Spacer()
                        if viewModel.noAlbumsCount == 0 && viewModel.isLoadingAlbumCounts {

                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                                .frame(width: 16, height: 16)
                        } else {
                            Text(verbatim: String(viewModel.noAlbumsCount))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(SidebarItem.noAlbums)

                    .listRowBackground((selectedItems.contains(.noAlbums)) ? Color.accentColor.opacity(0.12) : Color.clear)

                    ForEach(viewModel.userAlbums, id: \.localIdentifier) { album in
                        HStack {
                            Text(album.localizedTitle ?? "Untitled")
                            Spacer()
                            if let count = viewModel.albumCounts[album.localIdentifier] {
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("—")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tag(SidebarItem.album(album.localIdentifier))

                        .listRowBackground((selectedItems.contains(.album(album.localIdentifier))) ? Color.accentColor.opacity(0.12) : Color.clear)
                    }
                } label: {
                    HStack {
                        Text("My Albums")
                        Spacer()
                    }
                    .onTapGesture { isMyAlbumsExpanded.toggle() }
                }
            }
            Section {
                DisclosureGroup(isExpanded: $isSmartAlbumsExpanded) {
                    ForEach(viewModel.smartAlbums, id: \.localIdentifier) { album in
                        HStack {
                            Text(album.localizedTitle ?? "Untitled")
                            Spacer()
                            if let count = viewModel.albumCounts[album.localIdentifier] {
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("—")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tag(SidebarItem.album(album.localIdentifier))

                        .listRowBackground((selectedItems.contains(.album(album.localIdentifier))) ? Color.accentColor.opacity(0.12) : Color.clear)
                    }
                } label: {
                    HStack {
                        Text("Smart Albums")
                        Spacer()
                    }
                    .onTapGesture { isSmartAlbumsExpanded.toggle() }
                }
            }
        }
        .listStyle(.sidebar)
    }
}
