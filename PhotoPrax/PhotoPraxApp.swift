//  Prax-1207-0
//
//  PhotoPraxApp.swift
//  PhotoPrax
//
//  Created by Elmer Cat on 9/27/25.
//

import SwiftUI
import AppKit

@main
struct PhotoPraxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup(id: "main") {
            MainSceneRoot()
                .background(
                    WindowReader { window in
                        WindowCoordinator.shared.attachIfPending(newWindow: window)
                    }
                )
        }
        .commands {
            MainCommands()
        }
    }
}

struct MainSceneRoot: View {
    @StateObject private var viewModel = PhotoLibraryViewModel()
    
    var body: some View {
        ContentView()
            .environmentObject(viewModel)
    }
}

struct MainCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {

        CommandGroup(after: .systemServices) {
            Button("Settings...") {
                SettingsWindowManager.shared.show()
            }
            .keyboardShortcut(",", modifiers: [.command])
        }

        CommandGroup(after: .newItem) {
            Button("New Tab") {
                let keyWindow = NSApp.keyWindow
                WindowCoordinator.shared.requestNewTab(in: keyWindow)
                openWindow(id: "main")
            }
            .keyboardShortcut("t", modifiers: [.command])
        }
        CommandGroup(after: .textEditing) {
            Button("Select All") {
                // Use focused values to trigger select all
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            .keyboardShortcut("a", modifiers: [.command])
        }
        CommandGroup(after: .sidebar) {
            Button("Show/Hide Sidebar") {
                NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
        }
    }
}

final class WindowCoordinator {
    static let shared = WindowCoordinator()
    private var pendingTargetWindowNumber: Int?

    func requestNewTab(in keyWindow: NSWindow?) {
        pendingTargetWindowNumber = keyWindow?.windowNumber
    }

    func attachIfPending(newWindow: NSWindow) {
        guard let targetNumber = pendingTargetWindowNumber else { return }
        // Clear pending so we only attach once
        pendingTargetWindowNumber = nil
        if let target = NSApp.windows.first(where: { $0.windowNumber == targetNumber }) {
            target.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
        }
    }
}

struct WindowReader: NSViewRepresentable {
    var onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = WindowAccessorView()
        v.onResolve = onResolve
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowAccessorView: NSView {
        var onResolve: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window = window {
                onResolve?(window)
            }
        }
    }
}

