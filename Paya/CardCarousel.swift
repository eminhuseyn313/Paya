import SwiftUI

// MARK: - Card Carousel
//
// The real fix for "wall of cards" isn't fewer tabs — it's not stacking
// everything vertically at all. One hero chart per screen answers "what's
// the one thing worth seeing first"; everything secondary goes here,
// swiped through horizontally instead of scrolled past, so the vertical
// rhythm of a tab never becomes a wall regardless of how many small cards
// exist for it.

struct CardCarousel<Content: View>: View {
    let cardWidth: CGFloat
    @ViewBuilder var content: Content

    init(cardWidth: CGFloat = 260, @ViewBuilder content: () -> Content) {
        self.cardWidth = cardWidth
        self.content = content()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                content
            }
            .padding(.horizontal, 2)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }
}

/// Fixed-width wrapper so each carousel child lays out consistently
/// regardless of its own internal content length.
struct CarouselCard<Content: View>: View {
    let width: CGFloat
    @ViewBuilder var content: Content

    init(width: CGFloat = 260, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: width, alignment: .topLeading)
    }
}
