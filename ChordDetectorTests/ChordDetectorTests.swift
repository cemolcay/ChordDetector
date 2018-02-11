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
      ]) else { XCTFail("Old ultimate-guitar cookie no set.") }
    Alamofire.SessionManager.default.session.configuration.httpCookieStorage?.setCookie(cookie)

    Alamofire.request(chordUrl).responseString(completionHandler: {response in
      switch response.result {
      case .success(let string):
        guard let html = HTML(html: string, encoding: .utf8) else { return XCTFail("HTML not parsed.") }

        // Parse chord rows in result table and sort them in order to rating
        let chords = html
          .xpath("//table[@class=\"tresults  \"]//tr[contains(.,\"chords\")]")
          .sorted(by: {
            (($0.xpath("./td/span/b[@class=\"ratdig\"]").first?.text ?? "") as NSString).intValue >
              (($1.xpath("./td/span/b[@class=\"ratdig\"]").first?.text ?? "") as NSString).intValue
          })
        XCTAssertGreaterThan(chords.count, 0, "No chord found.")

        // Parse urls of chord rows
        let urls = chords.flatMap({ $0.xpath("./td/div/a[@class=\"song result-link js-search-spelling-link\"]").first })
        XCTAssertGreaterThan(urls.count, 0, "Chord URLs not parsed.")

        // Get most rated chord url
        let url = urls.first?["href"]
        XCTAssertNotNil(url, "Chord URL not found.")
      case .failure:
        // Request error
        XCTFail("URL Request error. Check internet connection.")
      }
    })
  }
}
