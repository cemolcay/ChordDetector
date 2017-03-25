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
  let statusItem = NSStatusBar.system().statusItem(withLength: -2)

  func applicationDidFinishLaunching(_ aNotification: Notification) {

    // StatusBarItem
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

    for (index, historyItem) in detector.history.enumerated() {
      let item = NSMenuItem(
        title: historyItem.name,
        action: #selector(historyItemDidPress(sender:)),
        keyEquivalent: "")
      item.tag = index
      menu.addItem(item)
    }

    if !detector.history.isEmpty {
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

  func historyItemDidPress(sender: NSMenuItem) {
    guard let url = URL(string: detector.history[sender.tag].url) else { return }
    NSWorkspace.shared().open(url)
  }

  func clearHistoryDidPress() {
    detector.history = []
    statusItem.menu = menu
  }
}
