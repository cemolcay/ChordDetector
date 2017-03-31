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

    guard let chordUrl = URL(string: url) else { return XCTFail("URL not parsed") }

    Alamofire.request(chordUrl).responseString(completionHandler: {response in
      switch response.result {
      case .success(let string):
        guard let html = HTML(html: string, encoding: .utf8) else { return XCTFail("HTML not parsed.") }
        let chords = html
          .xpath("//table[@class=\"tresults  \"]//tr[contains(.,\"chords\")]")
          .sorted(by: {
            (($0.xpath("./td/span/b[@class=\"ratdig\"]").first?.text ?? "") as NSString).intValue >
              (($1.xpath("./td/span/b[@class=\"ratdig\"]").first?.text ?? "") as NSString).intValue
          }).flatMap({ $0.xpath("./td/div/a[@class=\"song result-link js-search-spelling-link\"]").first })

        let url = chords.first?["href"]
        XCTAssertNotNil(url, "Chord not found.")
      case .failure:
        XCTFail("URL Request error. Check internet connection.")
      }
    })
  }
}
