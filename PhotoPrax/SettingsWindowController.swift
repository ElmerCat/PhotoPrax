//
//  SettingsWindowController.swift
//  PhotoPrax
//
//  Created by Elmer Cat on 12/7/25.
//

import Cocoa

class SettingsWindowController: NSWindowController {
    
    override var windowNibName: NSNib.Name? { "SettingsWindow" }
    
    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
}
final class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var windowController: SettingsWindowController?
    
    func show() {
        if let wc = windowController {
            wc.showWindow(nil)
            wc.window?.makeKeyAndOrderFront(nil)
            return
        }
        let wc = SettingsWindowController()
        windowController = wc
        wc.showWindow(nil)
        wc.window?.makeKeyAndOrderFront(nil)
    }
}
