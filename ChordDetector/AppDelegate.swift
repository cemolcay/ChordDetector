//
//  AppDelegate.swift
//  ChordDetector
//
//  Created by Cem Olcay on 24/03/2017.
//  Copyright © 2017 cemolcay. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  let detector = ChordDetector.shared
  let statusItem = NSStatusBar.system.statusItem(withLength: -2)

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    statusItem.menu = menu
    if let button = statusItem.button {
      button.image = NSImage(named: "menuBar")
      button.imageScaling = .scaleProportionallyUpOrDown
    }
  }

  // MARK: Menu

  var menu: NSMenu {
    let menu = NSMenu()

    // History
    let historyTitleItem = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
    historyTitleItem.isEnabled = false
    menu.addItem(historyTitleItem)

    for (index, historyItem) in detector.history.items.enumerated() {
      let item = NSMenuItem(
        title: historyItem.title,
        action: #selector(historyItemDidPress(sender:)),
        keyEquivalent: "")
      item.tag = index
      menu.addItem(item)
    }

    if !detector.history.items.isEmpty {
      menu.addItem(
        withTitle: "Clear History",
        action: #selector(clearHistoryDidPress),
        keyEquivalent: "")
    }

    // Quit
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "Quit",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "")

    return menu
  }

  @objc func historyItemDidPress(sender: NSMenuItem) {
    let url = detector.history.items[sender.tag].url
    NSWorkspace.shared.open(url)
  }

  @objc func clearHistoryDidPress() {
    detector.history.clear()
    statusItem.menu = menu
  }
}
