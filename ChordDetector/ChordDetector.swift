//
//  ChordDetector.swift
//  ChordDetector
//
//  Created by Cem Olcay on 24/03/2017.
//  Copyright © 2017 cemolcay. All rights reserved.
//

import Cocoa
import WebKit

// MARK: - UGItem

struct UGItem: Codable, Equatable {
  let artist: String
  let song: String
  let url: URL

  var title: String {
    return "\(artist) - \(song)"
  }

  var dictionaryValue: [String: Any] {
    guard let data = try? JSONEncoder().encode(self),
      let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
      else { return [:] }
    return dict
  }

  enum CodingKeys: String, CodingKey {
    case artist = "artist_name"
    case song = "song_name"
    case url = "tab_url"
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    artist = try values.decode(String.self, forKey: .artist)
    song = try values.decode(String.self, forKey: .song)
    url = try values.decode(URL.self, forKey: .url)
  }

  init?(dict: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
      let item = try? JSONDecoder().decode(UGItem.self, from: data)
      else { return nil }
    self = item
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(artist, forKey: .artist)
    try container.encode(song, forKey: .song)
    try container.encode(url, forKey: .url)
  }

  func pushNotification() {
    let notification = NSUserNotification()
    notification.title = "Chord Detected!"
    notification.informativeText = title
    notification.userInfo = dictionaryValue
    NSUserNotificationCenter.default.deliver(notification)
  }
}

// MARK: - History

class History {
  private(set) var items: [UGItem]
  private let historyKey = "history"
  private let limit = 20

  init() {
    if let data = UserDefaults.standard.data(forKey: historyKey),
      let history = try? PropertyListDecoder().decode([UGItem].self, from: data) {
      items = history
    } else {
      items = []
    }
    persist()
  }

  func clear() {
    items.removeAll()
    persist()
  }

  func push(item: UGItem) {
    guard items.contains(item) == false else { return }
    items.append(item)
    // Check limit
    if items.count > limit {
      items.removeFirst()
    }
    persist()
  }

  func persist() {
    // Save
    let defaults = UserDefaults.standard
    guard let data = try? PropertyListEncoder().encode(items) else { return }
    defaults.set(data, forKey: historyKey)
    defaults.synchronize()
    // Update UI
    if let appdelegate = NSApplication.shared.delegate as? AppDelegate {
      appdelegate.statusItem.menu = appdelegate.menu
    }
  }
}

// MARK: - ChordDetector

class ChordDetector: NSObject, WKNavigationDelegate, NSUserNotificationCenterDelegate {
  static let shared = ChordDetector()
  let history = History()
  let webView = WKWebView()

  private let spotifyNotificationName = "com.spotify.client.PlaybackStateChanged"
  private let itunesNotificationName = "com.apple.iTunes.playerInfo"

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
    searchChord(
      artist: artist,
      song: song)
  }

  func searchChord(artist: String, song: String) {
    var url = "https://www.ultimate-guitar.com/search.php?search_type=title&order=&value="
    url += "\(artist.replacingOccurrences(of: " ", with: "+"))+"
    url += "\(song.replacingOccurrences(of: " ", with: "+"))"

    guard let chordUrl = URL(string: url) else { return }
    webView.load(URLRequest(url: chordUrl))
  }

  // MARK: WKNavigationDelegate

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let script = """
    window.UGAPP.store.page.data.results
      .filter(function(item){ return (item.type == "Chords") })
      .sort(function(a, b){ return b.rating > a.rating })[0]
    """

    webView.evaluateJavaScript(script, completionHandler: { result, error in
      guard error == nil,
        let result = result as? [String: Any],
        let item = UGItem(dict: result)
        else { return }
      item.pushNotification()
      self.history.push(item: item)
    })
  }

  // MARK: NSUserNotificationCenterDelegate

  func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
    guard let dict = notification.userInfo,
      let item = UGItem(dict: dict)
      else { return }
    // Open url
    NSWorkspace.shared.open(item.url)
  }
}
