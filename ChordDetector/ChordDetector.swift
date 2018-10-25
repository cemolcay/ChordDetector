//
//  ChordDetector.swift
//  ChordDetector
//
//  Created by Cem Olcay on 24/03/2017.
//  Copyright © 2017 cemolcay. All rights reserved.
//

import Cocoa
import Alamofire
import Kanna
import SwiftyJSON

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

class ChordDetector: NSObject, NSUserNotificationCenterDelegate {
  static let shared = ChordDetector()

  private let spotifyNotificationName = "com.spotify.client.PlaybackStateChanged"
  private let itunesNotificationName = "com.apple.iTunes.playerInfo"
  private let historyKey = "history"

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
    NSUserNotificationCenter.default.delegate = self
    registerNotifications(for: [
      spotifyNotificationName,
      itunesNotificationName,
    ])

    guard let cookie = HTTPCookie(properties: [
      .domain: "www.ultimate-guitar.com",
      .path: "/",
      .name: "back_to_classic_ug",
      .value: "1",
      .secure: "TRUE",
      .expires: Date(timeIntervalSinceNow: 365*24*60)
    ]) else { return }
    Alamofire.SessionManager.default.session.configuration.httpCookieStorage?.setCookie(cookie)
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

    getChords(
      artist: artist,
      song: song)
  }

  // MARK: Chord Detection

  private func getChords(artist: String, song: String) {
    var url = "https://www.ultimate-guitar.com/search.php?search_type=title&order=&value="
    url += "\(artist.replacingOccurrences(of: " ", with: "+"))+"
    url += "\(song.replacingOccurrences(of: " ", with: "+"))"

    guard let chordUrl = URL(string: url) else { return }

    Alamofire.request(chordUrl).responseString(completionHandler: {response in
      switch response.result {
      case .success(let string):
        self.parseChords(
          string: string,
          artist: artist,
          song: song)
      case .failure:
        return
      }
    })
  }

  private func parseChords(string: String, artist: String, song: String) {
    guard let html = try? HTML(html: string, encoding: .utf8) else { return }
    let regexPattern = "(?<= window.UGAPP.store.page = )(.*)(?=;)"

    guard
      let script = html.xpath("//script")
        .compactMap({ $0.text })
        .filter({ $0.contains("window.UGAPP.store.page") })
        .first,
      let regex = try? NSRegularExpression(pattern: regexPattern, options: []),
      let match = regex.firstMatch(in: script, options: [], range: NSRange(0..<script.count)),
      let matchRange = Range(match.range(at: 0), in: script)
      else { return  }

    let jsonString = String(script[matchRange])
    let json = JSON(parseJSON: jsonString)
    let results = json["data"]["results"]

    guard let result = results
      .filter({ $1["type"].stringValue == "Chords" })
      .sorted(by: { $0.1["rating"].doubleValue > $1.1["rating"].doubleValue })
      .first.map({ $0.1 }),
      let url = result["tab_url"].url
      else { return }

    // Push a notification after 1sec of song change to bypass iTunes/Spotify notification.
    let notification = NSUserNotification()
    notification.title = "Chord Detected!"
    notification.informativeText = "\(artist) - \(song)"
    notification.userInfo = [
      "type": "chord",
      "name": "\(artist) - \(song)",
      "url": url.absoluteString,
    ]

    Timer.scheduledTimer(
      timeInterval: 5,
      target: self,
      selector: #selector(fireNotification(timer:)),
      userInfo: ["notification": notification],
      repeats: false)
  }

  @objc func fireNotification(timer: Timer) {
    guard let dict = timer.userInfo as? [String: Any],
      let notification = dict["notification"] as? NSUserNotification
      else { return }
    NSUserNotificationCenter.default.deliver(notification)
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
