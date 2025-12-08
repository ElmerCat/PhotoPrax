//  Prax-1207-0
//
//  SidebarItem.swift
//  PhotoPrax
//
//  Created by Elmer Cat on 9/28/25.
//

import Foundation

enum SidebarItem: Hashable, Sendable {
    case allPhotos
    case noAlbums
    case album(String)
    
    var resetID: String {
        switch self {
        case .allPhotos: return "ALL_PHOTOS"
        case .noAlbums: return "NO_ALBUMS"
        case .album(let id): return id
        }
    }
}
