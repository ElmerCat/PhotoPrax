//  Prax-11272
//
//  PreparationViewController.swift
//  PhotoPrax
//
//  Created by Elmer Cat on 11/26/25.
//

import Cocoa
import Combine


class PreparationViewController: NSViewController {
    
    // UI elements (assume these are connected via Interface Builder)
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    // The controller that handles database preparation and progress
    let dbPrepController = DatabasePreparationController()
    var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Bind status message to label
        dbPrepController.$statusMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.statusLabel.stringValue = message
            }
            .store(in: &cancellables)
        
        // Bind progress to progress bar
        dbPrepController.$progress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                self?.progressIndicator.doubleValue = progress * 100
            }
            .store(in: &cancellables)
        
        // Optionally, respond to step changes, errors, etc.
        
        dbPrepController.startPreparation()
    }
}

