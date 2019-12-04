//
//  ChordDetectorTests.swift
//  ChordDetectorTests
//
//  Created by Cem Olcay on 31/03/2017.
//  Copyright © 2017 cemolcay. All rights reserved.
//

import XCTest
import WebKit
@testable import Chord_Detector

class ChordDetectorTests: XCTestCase, WKNavigationDelegate {
  var webView = WKWebView()
  var wkExpectation = XCTestExpectation(description: "WKNavigationDelegate")
  let artist = "The Animals"
  let song = "House Of The Rising Sun"

  func testUltimateGuitarParse() {
    var url = "https://www.ultimate-guitar.com/search.php?search_type=title&order=&value="
    url += "\(artist.replacingOccurrences(of: " ", with: "+"))+"
    url += "\(song.replacingOccurrences(of: " ", with: "+"))"

    guard let chordUrl = URL(string: url) else { return XCTFail("URL not parsed.") }
    webView.navigationDelegate = self
    webView.load(URLRequest(url: chordUrl))
    wait(for: [wkExpectation], timeout: 10.0)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let js = """
    window.UGAPP.store.page.data.results
      .filter(function(item){ return (item.type == "Chords") })
      .sort(function(a, b){ return b.rating > a.rating })[0]
    """
    webView.evaluateJavaScript(js, completionHandler: { result, error in
      guard let json = result as? [String: Any],
        error == nil
        else { XCTFail("Can not evaluate javascript"); return }

      guard let url = json["tab_url"] as? String,
        let artist = json["artist_name"] as? String,
        let song = json["song_name"] as? String,
        let item = UGItem(dict: json)
        else { XCTFail("Can not serialize javascript object"); return }

      XCTAssertEqual(self.artist, artist)
      XCTAssertEqual(self.song, song)
      XCTAssertNotNil(URL(string: url), "Url is nil")
      XCTAssertEqual(self.artist, item.artist)
      XCTAssertEqual(self.song, item.song)
      XCTAssertEqual(url, item.url.absoluteString)
      self.wkExpectation.fulfill()
    })
  }
}
