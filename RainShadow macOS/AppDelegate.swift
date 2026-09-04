//
//  AppDelegate.swift
//  RainShadow macOS
//
//  Created by Laurens van Oorschot on 7/17/26.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        installNewGameMenuItem()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - New Game

    /// Installs File ▸ New Game (⌘N).
    ///
    /// The Xcode template's File menu already ships a "New" item on ⌘N wired to
    /// `newDocument:`, which nothing in a non-document app implements — so it sits
    /// there permanently greyed out. Repurposing it keeps ⌘N unambiguous instead
    /// of adding a second item competing for the same shortcut, and retires a dead
    /// entry in the process.
    ///
    /// Done in code rather than in `Main.storyboard` so the title and the selector
    /// behind it cannot drift apart.
    private func installNewGameMenuItem() {
        guard let mainMenu = NSApp.mainMenu else { return }

        // Fall back to creating the menu rather than returning: a silent no-op
        // here would leave the only way to restart the game invisible.
        let fileMenu: NSMenu
        if let existing = mainMenu.items.compactMap({ $0.submenu }).first(where: { $0.title == "File" }) {
            fileMenu = existing
        } else {
            let menu = NSMenu(title: "File")
            let host = NSMenuItem()
            host.submenu = menu
            mainMenu.insertItem(host, at: min(1, mainMenu.items.count))
            fileMenu = menu
        }

        let existing = fileMenu.items.first {
            $0.action == Selector(("newDocument:")) || $0.title == "New"
        }
        let item: NSMenuItem
        if let existing {
            item = existing
        } else {
            item = NSMenuItem()
            fileMenu.insertItem(item, at: 0)
            fileMenu.insertItem(.separator(), at: 1)
        }

        item.title = "New Game"
        item.keyEquivalent = "n"
        item.keyEquivalentModifierMask = [.command]
        item.action = #selector(startNewGame(_:))
        item.target = self
    }

    /// Discards the save and restarts from the opening.
    ///
    /// Confirmed first: progress lives in a single persisted snapshot with no
    /// slots and no undo, so a mis-clicked ⌘N would silently destroy a
    /// playthrough. Cancel is the default button.
    @objc private func startNewGame(_ sender: Any?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Start a new game?"
        alert.informativeText = """
            This permanently discards your current progress — the case intro, \
            everything you have inspected, your journal, and your wallet. \
            There is only one save, and this cannot be undone.
            """
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Discard and Start Over")

        guard alert.runModal() == .alertSecondButtonReturn else { return }

        if !GameBootstrap.startNewGame() {
            NSSound.beep()
        }
    }
}
