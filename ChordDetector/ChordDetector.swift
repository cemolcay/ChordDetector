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

// MARK: - HistoryItem

class HistoryItem: NSObject, NSCoding {
  var name: String
  var url: String

  init(name: String, url: String) {
    self.name = name
    self.url = url
    super.init()
  }

  convenience init?(notification: NSUserNotification) {
    guard let name = notification.userInfo?["name"] as? String,
      let url = notification.userInfo?["url"] as? String
      else { return nil }
    self.init(name: name, url: url)
  }

  // MARK: NSCoding

  required convenience init?(coder aDecoder: NSCoder) {
    guard let name = aDecoder.decodeObject(forKey: "name") as? String,
      let url = aDecoder.decodeObject(forKey: "url") as? String
      else { return nil }
    self.init(name: name, url: url)
  }

  func encode(with aCoder: NSCoder) {
    aCoder.encode(name, forKey: "name")
    aCoder.encode(url, forKey: "url")
  }

  // MARK: Equatable

  override func isEqual(_ object: Any?) -> Bool {
    if let item = object as? HistoryItem {
      return item.name == name && item.url == url
    }
    return super.isEqual(object)
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
      if let data = UserDefaults.standard.object(forKey: historyKey) as? Data,
        let history = NSKeyedUnarchiver.unarchiveObject(with: data) as? [HistoryItem] {
        return history
      }

      // Create new
      let defaults = UserDefaults.standard
      defaults.set(NSKeyedArchiver.archivedData(withRootObject: [HistoryItem]()), forKey: historyKey)
      defaults.synchronize()
      return []
    } set {
      var newHistory = newValue
      if newHistory.count > 20 {
        newHistory.removeFirst()
      }

      let defaults = UserDefaults.standard
      defaults.set(NSKeyedArchiver.archivedData(withRootObject: newHistory), forKey: historyKey)
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
    guard let html = HTML(html: string, encoding: .utf8) else { return }
    let chords = html
      .xpath("//table[@class=\"tresults\"]//tr[contains(.,\"chords\")]")
      .sorted(by: {
        (($0.xpath("./td/span/b[@class=\"ratdig\"]").first?.text ?? "") as NSString).intValue >
        (($1.xpath("./td/span/b[@class=\"ratdig\"]").first?.text ?? "") as NSString).intValue
      }).flatMap({ $0.xpath("./td/div/a[@class=\"song result-link\"]").first })

    guard let url = chords.first?["href"] else { return }

    let notification = NSUserNotification()
    notification.title = "Chord Detected!"
    notification.informativeText = "\(artist) - \(song)"
    notification.userInfo = [
      "type": "chord",
      "name": "\(artist) - \(song)",
      "url": url,
    ]

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
      if let appdelegate = NSApplication.shared().delegate as? AppDelegate {
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
    NSWorkspace.shared().open(url)
  }
}
