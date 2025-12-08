//  Prax-1207-0
//  AppDelegate.swift
//  PhotoPrax
//
//  Created by Elmer Cat on 12/7/25.
//



import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true
     
        print("AppDelegate - applicationDidFinishLaunching")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        print("AppDelegate - applicationWillTerminate")

    }
}

