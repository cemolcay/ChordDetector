//
//  ChordDetectorTests.swift
//  ChordDetectorTests
//
//  Created by Cem Olcay on 31/03/2017.
//  Copyright © 2017 cemolcay. All rights reserved.
//

import XCTest
import Kanna
import Alamofire
import SwiftyJSON

class ChordDetectorTests: XCTestCase {

  func testUltimateGuitarParse() {
    let artist = "The Animals"
    let song = "House of the rising sun"
    var url = "https://www.ultimate-guitar.com/search.php?search_type=title&order=&value="
    url += "\(artist.replacingOccurrences(of: " ", with: "+"))+"
    url += "\(song.replacingOccurrences(of: " ", with: "+"))"

    guard let chordUrl = URL(string: url) else { return XCTFail("URL not parsed.") }

    // Set old ultimate-gutar cookie
    guard let cookie = HTTPCookie(properties: [
      .domain: "www.ultimate-guitar.com",
      .path: "/",
      .name: "back_to_classic_ug",
      .value: "1",
      .secure: "TRUE",
      .expires: Date(timeIntervalSinceNow: 365*24*60)
      ]) else { fatalError("Old ultimate-guitar cookie no set.") }
    Alamofire.SessionManager.default.session.configuration.httpCookieStorage?.setCookie(cookie)
    
    // Make request
    let networkExpectation = expectation(description: "UltimateGuitar network request expectation.")
    Alamofire.request(chordUrl)
    .responseString(completionHandler: { response in
      switch response.result {
      case .success(let string):
        guard let html = try? HTML(html: string, encoding: .utf8)
          else { return XCTFail("HTML not parsed.") }

        let regexPattern = "(?<= window.UGAPP.store.page = )(.*)(?=;)"

        guard
          let script = html.xpath("//script")
            .compactMap({ $0.text })
            .filter({ $0.contains("window.UGAPP.store.page") })
            .first,
          let regex = try? NSRegularExpression(pattern: regexPattern, options: []),
          let match = regex.firstMatch(in: script, options: [], range: NSRange(0..<script.count)),
          let matchRange = Range(match.range(at: 0), in: script)
          else { return XCTFail("Can not find the window.UGAPP.store.page script.") }

        let jsonString = String(script[matchRange])
        let json = JSON(parseJSON: jsonString)
        let results = json["data"]["results"]
        XCTAssertGreaterThanOrEqual(results.count, 0, "JSON results can not parsed.")

        guard let result = results
          .filter({ $1["type"].stringValue == "Chords" })
          .sorted(by: { $0.1["rating"].doubleValue > $1.1["rating"].doubleValue })
          .first
          .map({ $0.1 })
          else { return XCTFail("Can not find the result") }

        let url = result["tab_url"].url
        XCTAssertNotNil(url, "Can not get the URL")
        networkExpectation.fulfill()

      case .failure:
        // Request error
        XCTFail("URL Request error. Check internet connection.")
      }
    })

    wait(for: [networkExpectation], timeout: 10.0)
  }
}
