import SwiftUI

struct AdaptiveLayout {
    let horizontalSizeClass: UserInterfaceSizeClass?

    var isRegular: Bool { horizontalSizeClass == .regular }

    var gridColumns: [GridItem] {
        let count = isRegular ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var cardWidth: CGFloat { isRegular ? 180 : 140 }
    var cardHeight: CGFloat { isRegular ? 260 : 200 }
    var gridCardHeight: CGFloat { isRegular ? 220 : 160 }
    var carouselHeight: CGFloat { isRegular ? 380 : 220 }
    var detailsPosterHeight: CGFloat { isRegular ? 350 : 200 }
}
