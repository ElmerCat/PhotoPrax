//  Prax-1207-0
//
//  AssetsListView.swift
//  PhotoPrax
//
import SwiftUI
import Combine
@preconcurrency import Photos

// MARK: - Column definitions and preferences

enum AssetColumn: String, CaseIterable, Identifiable {
    case thumbnail, date, time, type, duration, size, favorite
    var id: String { rawValue }
    var title: String {
        switch self {
        case .thumbnail: return "Thumbnail"
        case .date: return "Date"
        case .time: return "Time"
        case .type: return "Type"
        case .duration: return "Duration"
        case .size: return "Size"
        case .favorite: return "★"
        }
    }
}

final class ColumnsPreferences: ObservableObject {
    @Published var visible: Set<AssetColumn> = [.thumbnail, .date, .type, .size, .favorite]
    @Published var sortOrder: [SortDescriptor<AssetRowModel>] = [
        SortDescriptor(\AssetRowModel.date, order: .reverse)
    ]
}

// MARK: - Row model

struct AssetRowModel: Identifiable, Hashable {
    let id: String
    let asset: PHAsset

    var date: Date? { asset.creationDate }
    var type: String { asset.mediaType == .video ? "Video" : "Photo" }
    var duration: TimeInterval { asset.mediaType == .video ? asset.duration : 0 }
    var pixelSize: String {
        (asset.pixelWidth > 0 && asset.pixelHeight > 0)
        ? "\(asset.pixelWidth) × \(asset.pixelHeight)" : "—"
    }
    var isFavorite: Bool { asset.isFavorite }
}

// MARK: - View

struct AssetsListView: View {
    let assets: [PHAsset]
    let isLoading: Bool
    let resetID: String?
    @Binding var selectedAssetIDs: Set<String>

    @StateObject private var columns = ColumnsPreferences()

    private var rows: [AssetRowModel] {
        assets.map { AssetRowModel(id: $0.localIdentifier, asset: $0) }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Optional toolbar-like menu for columns
                HStack {
                    Menu("Columns") {
                        ForEach(AssetColumn.allCases) { col in
                            let isOn = columns.visible.contains(col)
                            Button(isOn ? "Hide \(col.title)" : "Show \(col.title)") {
                                if isOn { columns.visible.remove(col) } else { columns.visible.insert(col) }
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                Table(sortedRows, selection: $selectedAssetIDs, sortOrder: $columns.sortOrder) {
                    if columns.visible.contains(.thumbnail) {
                        TableColumn(AssetColumn.thumbnail.title) { row in
                            PhotoThumbnailView(asset: row.asset, size: 60)
                                .cornerRadius(6)
                        }
                        .width(72)
                    }
                    if columns.visible.contains(.date) {
                        TableColumn(AssetColumn.date.title) { row in
                            if let d = row.date { Text(d, style: .date) } else { Text("—").foregroundStyle(.tertiary) }
                        }
                        .width(min: 120, ideal: 140)
                    }
                    if columns.visible.contains(.time) {
                        TableColumn(AssetColumn.time.title) { row in
                            if let d = row.date { Text(d, style: .time).foregroundStyle(.secondary) } else { Text("—").foregroundStyle(.tertiary) }
                        }
                        .width(min: 80, ideal: 100)
                    }
                    if columns.visible.contains(.type) {
                        TableColumn(AssetColumn.type.title) { row in
                            Text(row.type).foregroundStyle(.secondary)
                        }
                        .width(min: 60, ideal: 80)
                    }
                    if columns.visible.contains(.duration) {
                        TableColumn(AssetColumn.duration.title) { row in
                            Text(formatDuration(row.duration)).monospacedDigit()
                        }
                        .width(min: 70, ideal: 90)
                    }
                    if columns.visible.contains(.size) {
                        TableColumn(AssetColumn.size.title) { row in
                            Text(row.pixelSize).foregroundStyle(.secondary)
                        }
                        .width(min: 110, ideal: 130)
                    }
                    if columns.visible.contains(.favorite) {
                        TableColumn(AssetColumn.favorite.title) { row in
                            if row.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                        }
                        .width(28)
                    }
                }
            }
            .opacity(isLoading ? 0.6 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: isLoading)

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.regular)
                        .frame(width: 20, height: 20)
                    Text("Loading…")
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .transition(.opacity)
            }
        }
        .id(resetID)
        .transaction { t in t.disablesAnimations = true }
    }

    // MARK: - Sorting and Selection

    private var sortedRows: [AssetRowModel] {
        rows.sorted(using: columns.sortOrder)
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

#Preview {
    AssetsListView(assets: [], isLoading: false, resetID: nil, selectedAssetIDs: .constant([]))
}
