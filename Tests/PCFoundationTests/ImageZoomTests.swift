// SPDX-License-Identifier: Apache-2.0
// ImageZoomTests.swift - The zoom arithmetic the quick preview and the viewer share (F-389).

import CoreGraphics
import XCTest
@testable import PCFoundation

final class ImageZoomTests: XCTestCase {

    // MARK: - Fit

    func testFitUsesTheTighterOfTheTwoAxes() {
        // A wide image in a square viewport is limited by its width, a tall one by its height.
        XCTAssertEqual(ImageZoom.fitScale(image: CGSize(width: 400, height: 100),
                                          in: CGSize(width: 200, height: 200)), 0.5, accuracy: 0.0001)
        XCTAssertEqual(ImageZoom.fitScale(image: CGSize(width: 100, height: 400),
                                          in: CGSize(width: 200, height: 200)), 0.5, accuracy: 0.0001)
    }

    func testFitScalesUpASmallImage() {
        // Fit means "fill the viewport as far as the aspect ratio allows", in both directions. What must
        // not scale up is the *initial* scale; see below.
        XCTAssertEqual(ImageZoom.fitScale(image: CGSize(width: 50, height: 50),
                                          in: CGSize(width: 200, height: 200)), 4, accuracy: 0.0001)
    }

    func testFitOfAnEmptyOrCollapsedThingIsOneRatherThanNaN() {
        // The collapsed sidebar is width 0 and the panel asks anyway, so this is a real case and not a
        // defensive flourish: 200/0 is infinity, and an infinite magnification takes AppKit with it.
        XCTAssertEqual(ImageZoom.fitScale(image: .zero, in: CGSize(width: 200, height: 200)), 1)
        XCTAssertEqual(ImageZoom.fitScale(image: CGSize(width: 200, height: 200), in: .zero), 1)
        XCTAssertEqual(ImageZoom.fitScale(image: CGSize(width: 200, height: 200),
                                          in: CGSize(width: 0, height: 100)), 1)
    }

    func testFitStaysInsideTheSupportedRange() {
        // A 12 000 px scan in a sidebar wants 0.025, which is below the smallest stop.
        let tiny = ImageZoom.fitScale(image: CGSize(width: 12_000, height: 12_000),
                                      in: CGSize(width: 300, height: 300))
        XCTAssertEqual(tiny, ImageZoom.minScale)
        let huge = ImageZoom.fitScale(image: CGSize(width: 1, height: 1),
                                      in: CGSize(width: 4000, height: 4000))
        XCTAssertEqual(huge, ImageZoom.maxScale)
    }

    // MARK: - Initial scale

    func testASmallImageOpensAtOneHundredPercent() {
        XCTAssertEqual(ImageZoom.initialScale(image: CGSize(width: 16, height: 16),
                                              in: CGSize(width: 300, height: 400)), 1)
    }

    func testABigImageOpensFitted() {
        XCTAssertEqual(ImageZoom.initialScale(image: CGSize(width: 3000, height: 2000),
                                              in: CGSize(width: 300, height: 200)), 0.1, accuracy: 0.0001)
    }

    // MARK: - Stepping

    func testSteppingWalksTheLadderAndStopsAtTheEnds() {
        XCTAssertEqual(ImageZoom.next(after: 1, zoomingIn: true), 1.5)
        XCTAssertEqual(ImageZoom.next(after: 1, zoomingIn: false), 0.75)
        XCTAssertEqual(ImageZoom.next(after: ImageZoom.maxScale, zoomingIn: true), ImageZoom.maxScale)
        XCTAssertEqual(ImageZoom.next(after: ImageZoom.minScale, zoomingIn: false), ImageZoom.minScale)
    }

    func testSteppingFromBetweenStopsLandsOnTheNextOne() {
        // The interesting case: a fit scale is almost never a stop, and zooming in from 0.42 must go to
        // 0.5 rather than back to 0.33 or straight to 1.
        XCTAssertEqual(ImageZoom.next(after: 0.42, zoomingIn: true), 0.5)
        XCTAssertEqual(ImageZoom.next(after: 0.42, zoomingIn: false), 0.33)
    }

    func testSteppingIsMonotonicAcrossTheWholeLadder() {
        // Walking up from the bottom must visit every stop and terminate — a wrong comparison here turns
        // "zoom in" into a control that sticks, which is exactly what the epsilon is for.
        var scale = ImageZoom.minScale
        var visited = [scale]
        for _ in 0..<50 {
            let next = ImageZoom.next(after: scale, zoomingIn: true)
            if next == scale { break }
            XCTAssertGreaterThan(next, scale)
            visited.append(next)
            scale = next
        }
        XCTAssertEqual(visited, ImageZoom.stops)
        for _ in 0..<50 {
            let next = ImageZoom.next(after: scale, zoomingIn: false)
            if next == scale { break }
            XCTAssertLessThan(next, scale)
            scale = next
        }
        XCTAssertEqual(scale, ImageZoom.minScale)
    }

    func testAnUnusableScaleIsTreatedAsOneHundredPercent() {
        XCTAssertEqual(ImageZoom.clamped(0), 1)
        XCTAssertEqual(ImageZoom.clamped(-2), 1)
        XCTAssertEqual(ImageZoom.clamped(.nan), 1)
        XCTAssertEqual(ImageZoom.clamped(.infinity), 1)
    }

    // MARK: - The label

    func testPercentTextRoundsButNeverToZero() {
        XCTAssertEqual(ImageZoom.percentText(1), "100%")
        XCTAssertEqual(ImageZoom.percentText(0.5), "50%")
        XCTAssertEqual(ImageZoom.percentText(16), "1600%")
        XCTAssertEqual(ImageZoom.percentText(0.33), "33%")
        // Below 10% one decimal survives, so a fitted scan says 5.5% instead of "6%" — and a fit that
        // lands at exactly 5% still says "5%" rather than "5.0%".
        XCTAssertEqual(ImageZoom.percentText(0.055), "5.5%")
        XCTAssertEqual(ImageZoom.percentText(0.05), "5%")
    }
}
