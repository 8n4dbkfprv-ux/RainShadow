import CoreGraphics
import Testing
@testable import RainShadowCore

struct IENativeViewportTests {
    @Test func everyZoomStepScalesTheBufferNotTheSourcePixel() {
        let native = OfficeInteriorScale.cameraScaleAt100Percent
        for step in CameraZoom.engineStepRange {
            let percent = CameraZoom.percent(forStep: step)
            let frame = IENativeViewport(viewSize: CGSize(width: 1280, height: 720),
                                         cameraCenter: CGPoint(x: 700.2, y: -81.8),
                                         cameraScale: native * percent / 100, nativeScale: native)
            #expect(frame.width == Int(1280 * percent / 100))
            #expect(frame.height == Int(720 * percent / 100))
            #expect(frame.unitsPerPixel == native)
            #expect(frame.pixel(frame.worldCenter(x: 19, y: 27)) == CGPoint(x: 19.5, y: 27.5))
            #expect(abs(frame.worldRect.midX - 700.2) <= native / 2)
            #expect(abs(frame.worldRect.midY + 81.8) <= native / 2)
        }
    }

    @Test func fractionalViewSizeTruncatesAndResizeRevealsMorePixels() {
        let small = IENativeViewport(viewSize: CGSize(width: 640.9, height: 360.9), cameraCenter: .zero,
                                     cameraScale: 1, nativeScale: 1)
        let large = IENativeViewport(viewSize: CGSize(width: 1280, height: 720), cameraCenter: .zero,
                                     cameraScale: 1, nativeScale: 1)
        #expect(small.width == 640 && small.height == 360)
        #expect(large.width == small.width * 2 && large.height == small.height * 2)
        #expect(small.unitsPerPixel == large.unitsPerPixel)
    }
}
