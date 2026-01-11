import SwiftUI

enum DisplayMode: Hashable {
    case filteredOnly
    case highlighted
    case excludedOnly
}

struct FilteredLine: Hashable {
    let text: String
    let isMatch: Bool
}
