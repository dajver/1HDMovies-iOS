import Foundation
import SwiftSoup

extension Elements {
    func eachAttr(_ key: String) throws -> [String] {
        return try array().map { try $0.attr(key) }
    }

    func eachText() throws -> [String] {
        return try array().map { try $0.text() }
    }

    func element(at index: Int) -> Element {
        return array()[index]
    }

    var count: Int {
        return array().count
    }

    func textNodes() -> [TextNode] {
        return array().flatMap { $0.textNodes() }
    }
}
