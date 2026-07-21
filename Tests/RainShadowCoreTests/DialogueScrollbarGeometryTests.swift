import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

struct DialogueScrollbarGeometryTests {
    @Test func nonScrollableHidesThumbInsteadOfStretchingFullTrack() {
        let track = CGRect(x: -15, y: -100, width: 30, height: 200)
        let layout = DialogueScrollbarGeometry.thumbLayout(
            trackRect: track,
            viewportExtent: 180,
            contentExtent: 180,
            scrollOffset: 0
        )
        #expect(!layout.isScrollable)
        #expect(!layout.thumbVisible)
        #expect(layout.thumbRect == .zero)
    }

    @Test func scrollableThumbStaysInsideTrackWithSaneHeight() {
        let track = CGRect(x: -15, y: -120, width: 30, height: 240)
        let viewport: CGFloat = 120
        let content: CGFloat = 400
        let layout = DialogueScrollbarGeometry.thumbLayout(
            trackRect: track,
            viewportExtent: viewport,
            contentExtent: content,
            scrollOffset: 0
        )
        #expect(layout.isScrollable)
        #expect(layout.thumbVisible)
        #expect(DialogueScrollbarGeometry.thumbIsInsideTrack(thumb: layout.thumbRect, track: track))
        #expect(layout.thumbRect.height >= DialogueScrollbarGeometry.minThumbHeight - 0.001)
        #expect(layout.thumbRect.height <= track.height * DialogueScrollbarGeometry.maxThumbTrackFraction + 0.001)
        #expect(layout.thumbRect.width <= track.width)
        #expect(layout.thumbRect.width >= 12)
        // Top-aligned at scroll 0.
        #expect(abs(layout.thumbRect.maxY - track.maxY) < 0.5)
    }

    @Test func scrollableThumbTravelsWithOffset() {
        let track = CGRect(x: 0, y: 0, width: 28, height: 200)
        let top = DialogueScrollbarGeometry.thumbLayout(
            trackRect: track,
            viewportExtent: 100,
            contentExtent: 300,
            scrollOffset: 0
        )
        let bottom = DialogueScrollbarGeometry.thumbLayout(
            trackRect: track,
            viewportExtent: 100,
            contentExtent: 300,
            scrollOffset: 200
        )
        #expect(top.thumbVisible && bottom.thumbVisible)
        #expect(bottom.thumbRect.midY < top.thumbRect.midY)
        #expect(DialogueScrollbarGeometry.thumbIsInsideTrack(thumb: bottom.thumbRect, track: track))
        #expect(abs(bottom.thumbRect.minY - track.minY) < 0.5)
    }

    @Test func thumbNeverExceedsTrackOrInverts() {
        let track = CGRect(x: -12, y: -80, width: 24, height: 160)
        for content in [161, 200, 400, 800] as [CGFloat] {
            for offset in [0, 50, 200, 999] as [CGFloat] {
                let layout = DialogueScrollbarGeometry.thumbLayout(
                    trackRect: track,
                    viewportExtent: 100,
                    contentExtent: content,
                    scrollOffset: offset
                )
                if layout.thumbVisible {
                    #expect(layout.thumbRect.height > 0)
                    #expect(layout.thumbRect.width > 0)
                    #expect(DialogueScrollbarGeometry.thumbIsInsideTrack(thumb: layout.thumbRect, track: track))
                    #expect(layout.thumbRect.minY <= layout.thumbRect.maxY)
                }
            }
        }
    }

    @Test func scrollbarNodeUsesShippedGeometryHelper() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("RainShadow Shared/UI/DialogueScrollbarNode.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("DialogueScrollbarGeometry.thumbLayout"))
        #expect(source.contains("thumb.isHidden = !layout.thumbVisible"))
        // Old full-track non-scrollable stretch must be gone.
        #expect(!source.contains(": trackRect.height"))
        #expect(!source.contains("trackRect.height * visibleFraction"))
    }
}
