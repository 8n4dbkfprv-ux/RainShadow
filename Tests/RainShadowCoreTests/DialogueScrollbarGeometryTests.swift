import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RainShadowCore

struct DialogueScrollbarGeometryTests {
    @Test func shippedScrollBoxIsSquareAndFillsCanvas() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(
            "RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_scroll_thumb_fantasy_v01.png"
        )
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let width = image.width
        let height = image.height
        #expect(width == 96)
        #expect(height == 96)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let visibleRows = (0..<height).filter { y in
            (0..<width).contains { x in
                pixels[(y * width + x) * 4 + 3] > 12
            }
        }
        let firstVisibleRow = try #require(visibleRows.first)
        let lastVisibleRow = try #require(visibleRows.last)
        #expect(firstVisibleRow <= height / 20)
        #expect(lastVisibleRow >= height - height / 20 - 1)
    }

    @Test func shippedTrackUsesWarmFantasyArtwork() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(
            "RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_scroll_track_fantasy_v01.png"
        )
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.height > image.width * 8)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(data: &pixel, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        #expect(pixel[0] > pixel[1] && pixel[1] > pixel[2])
        #expect(pixel[3] > 200)
    }

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

    /// Classic scroll bars share borders: no gap between the arrow buttons and the
    /// track, and the scroll box spans the full channel width.
    @Test func chromeAssemblesFlushAndThumbFillsTrackWidth() {
        let bounds = CGRect(x: -15, y: -150, width: 30, height: 300)
        let chrome = DialogueScrollbarGeometry.chromeLayout(bounds: bounds)

        #expect(chrome.upButton.width == chrome.upButton.height)
        #expect(chrome.downButton.width == chrome.downButton.height)
        #expect(abs(chrome.upButton.maxY - bounds.maxY) < 0.001)
        #expect(abs(chrome.downButton.minY - bounds.minY) < 0.001)
        #expect(abs(chrome.track.minY - chrome.downButton.maxY) < 0.001)
        #expect(abs(chrome.track.maxY - chrome.upButton.minY) < 0.001)
        #expect(chrome.track.width == bounds.width)

        let thumb = DialogueScrollbarGeometry.thumbLayout(
            trackRect: chrome.track,
            viewportExtent: 100,
            contentExtent: 400,
            scrollOffset: 0
        )
        #expect(thumb.thumbVisible)
        #expect(abs(thumb.thumbRect.width - chrome.track.width) < 0.001)
    }

    @Test func scrollableThumbIsProportionalAndStaysInsideTrack() {
        let track = CGRect(x: -15, y: -120, width: 30, height: 240)
        let layout = DialogueScrollbarGeometry.thumbLayout(
            trackRect: track,
            viewportExtent: 120,
            contentExtent: 400,
            scrollOffset: 0
        )
        #expect(layout.isScrollable)
        #expect(layout.thumbVisible)
        #expect(DialogueScrollbarGeometry.thumbIsInsideTrack(thumb: layout.thumbRect, track: track))
        #expect(abs(layout.thumbRect.width - track.width) < 0.001)
        #expect(abs(layout.thumbRect.height - track.height * 120 / 400) < 0.001)
        #expect(abs(layout.thumbRect.maxY - track.maxY) < 0.5)
    }

    @Test func scrollBoxShrinksWithContentAndKeepsAMinimumTarget() {
        let track = CGRect(x: -15, y: -120, width: 30, height: 240)
        let slightOverflow = DialogueScrollbarGeometry.thumbLayout(
            trackRect: track,
            viewportExtent: 200,
            contentExtent: 201,
            scrollOffset: 0
        )
        let largeOverflow = DialogueScrollbarGeometry.thumbLayout(
            trackRect: track,
            viewportExtent: 100,
            contentExtent: 1_000,
            scrollOffset: 0
        )

        #expect(slightOverflow.thumbVisible && largeOverflow.thumbVisible)
        #expect(abs(slightOverflow.thumbRect.height - track.height * 200 / 201) < 0.001)
        #expect(abs(largeOverflow.thumbRect.height - track.width) < 0.001)
        #expect(slightOverflow.thumbRect.height > largeOverflow.thumbRect.height)
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
                    #expect(layout.thumbRect.height >= min(track.width, track.height))
                }
            }
        }
    }

    @Test func arrowAndPageStepsFollowSystem7() {
        #expect(DialogueScrollbarGeometry.arrowStep(lineHeight: 21) == 21)
        #expect(DialogueScrollbarGeometry.pageStep(viewportExtent: 200, lineHeight: 21) == 179)
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
        #expect(source.contains("dialogue_scroll_thumb_fantasy_v01"))
        #expect(source.contains("thumb.layout(size: thumbRect.size)"))
        #expect(!source.contains("dialogue_scroll_area_v06"))

    }
}
