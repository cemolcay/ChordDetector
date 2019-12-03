//
//  ChordDetector.swift
//  ChordDetector
//
//  Created by Cem Olcay on 24/03/2017.
//  Copyright © 2017 cemolcay. All rights reserved.
//

import Cocoa
import WebKit

// MARK: - HistoryItem

struct HistoryItem: Codable, Equatable {
  var name: String
  var url: String

  init(name: String, url: String) {
    self.name = name
    self.url = url
  }

  init?(notification: NSUserNotification) {
    guard let name = notification.userInfo?["name"] as? String,
      let url = notification.userInfo?["url"] as? String
      else { return nil }
    self = HistoryItem(name: name, url: url)
  }

  // MARK: Equatable

  static func == (lhs: HistoryItem, rhs: HistoryItem) -> Bool {
    return lhs.name == rhs.name && lhs.url == rhs.url
  }
}

// MARK: - ChordDetector

class ChordDetector: NSObject, NSUserNotificationCenterDelegate, WKNavigationDelegate {
  static let shared = ChordDetector()

  private let spotifyNotificationName = "com.spotify.client.PlaybackStateChanged"
  private let itunesNotificationName = "com.apple.iTunes.playerInfo"
  private let historyKey = "history"

  let webView = WKWebView()

  // MARK: History

  var history: [HistoryItem] {
    get {
      if let data = UserDefaults.standard.data(forKey: historyKey),
        let history = try? PropertyListDecoder().decode([HistoryItem].self, from: data) {
        return history
      }

      // Create new
      let defaults = UserDefaults.standard
      guard let data = try? PropertyListEncoder().encode([HistoryItem]()) else { return [] }
      defaults.set(data, forKey: historyKey)
      defaults.synchronize()
      return []
    } set {
      var newHistory = newValue
      if newHistory.count > 20 {
        newHistory.removeFirst()
      }

      let defaults = UserDefaults.standard
      guard let data = try? PropertyListEncoder().encode(newHistory) else { return }
      defaults.set(data, forKey: historyKey)
      defaults.synchronize()
    }
  }

  // MARK: Lifecycle

  override init() {
    super.init()
    webView.navigationDelegate = self
    NSUserNotificationCenter.default.delegate = self
    registerNotifications(for: [
      spotifyNotificationName,
      itunesNotificationName,
    ])
  }

 // MARK: Player Notifications

  private func registerNotifications(for items: [String]) {
    for item in items {
      DistributedNotificationCenter.default().addObserver(
        self,
        selector: #selector(playerItemDidChange(notification:)),
        name: NSNotification.Name(rawValue: item),
        object: nil)
    }
  }

  @objc private func playerItemDidChange(notification: NSNotification) {
    guard let artist = notification.userInfo?["Artist"] as? String,
      let song = notification.userInfo?["Name"] as? String,
      notification.userInfo?["Player State"] as? String == "Playing"
      else { return }

    var url = "https://www.ultimate-guitar.com/search.php?search_type=title&order=&value="
    url += "\(artist.replacingOccurrences(of: " ", with: "+"))+"
    url += "\(song.replacingOccurrences(of: " ", with: "+"))"
    guard let chordUrl = URL(string: url) else { return }
    webView.load(URLRequest(url: chordUrl))
  }

  // MARK: WKNavigationDelegate

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let js = """
    window.UGAPP.store.page.data.results
      .filter(function(item){ return (item.type == "Chords") })
      .sort(function(a, b){ return b.rating > a.rating })[0]
    """
    webView.evaluateJavaScript(js, completionHandler: { result, error in
      guard let json = result as? [String: Any],
        error == nil
        else { return }

      guard let url = json["tab_url"] as? String,
        let artist = json["artist_name"] as? String,
        let song = json["song_name"] as? String
       else { return }

      // Push a notification.
      let notification = NSUserNotification()
      notification.title = "Chord Detected!"
      notification.informativeText = "\(artist) - \(song)"
      notification.userInfo = [
        "type": "chord",
        "name": "\(artist) - \(song)",
        "url": url,
      ]
      NSUserNotificationCenter.default.deliver(notification)
    })
  }

  // MARK: NSUserNotificationCenterDelegate

  func userNotificationCenter(_ center: NSUserNotificationCenter, didDeliver notification: NSUserNotification) {
    guard let historyItem = HistoryItem(notification: notification),
      notification.userInfo?["type"] as? String == "chord"
      else { return }

    // Update history
    if !history.contains(historyItem) {
      history.append(historyItem)
      if let appdelegate = NSApplication.shared.delegate as? AppDelegate {
        appdelegate.statusItem.menu = appdelegate.menu
      }
    }
  }

  func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
    guard let historyItem = HistoryItem(notification: notification),
      let url = URL(string: historyItem.url),
      notification.userInfo?["type"] as? String == "chord"
      else { return }

    // Open url
    NSWorkspace.shared.open(url)
  }
}
