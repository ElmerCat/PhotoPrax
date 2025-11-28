//  Prax-11272
//
//
//  DatabasePreparationController.swift
//  PhotoPrax
//
//  Handles Photos authorization and database preparation, publishing progress for UI updates.

import Foundation
import Combine
import Photos

class DatabasePreparationController: ObservableObject {
    enum PreparationStep: String {
        case waitingForAuthorization
        case authorizing
        case buildingDatabase
        case completed
        case failed
    }
    
    @Published var preparationStep: PreparationStep = .waitingForAuthorization
    @Published var progress: Double = 0.0 // 0.0 to 1.0
    @Published var statusMessage: String = "Waiting to begin..."
    @Published var error: Error?
    
    func startPreparation() {
        self.preparationStep = .authorizing
        self.statusMessage = "Requesting access to Photos Library..."
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if status == .authorized {
                    self.preparationStep = .buildingDatabase
                    self.statusMessage = "Building database..."
                    self.buildDatabase()
                } else {
                    self.preparationStep = .failed
                    self.statusMessage = "Authorization denied."
                }
            }
        }
    }
    
    private func buildDatabase() {
        // Example: Simulate progress. Replace with real asset fetching and DB code.
        let total = 100
        for i in 1...total {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.01) {
                self.progress = Double(i) / Double(total)
                self.statusMessage = "Processing item \(i) of \(total)..."
                if i == total {
                    self.preparationStep = .completed
                    self.statusMessage = "Database preparation complete."
                }
            }
        }
    }
}
