import Testing

@testable import PeekabooTypes

@Suite("Portable geometry")
struct GeometryTests {
    @Test("rect exposes derived coordinates")
    func derivedCoordinates() {
        let rect = PBRect(x: 10, y: 20, width: 100, height: 50)

        #expect(rect.minX == 10)
        #expect(rect.minY == 20)
        #expect(rect.maxX == 110)
        #expect(rect.maxY == 70)
        #expect(rect.center == PBPoint(x: 60, y: 45))
    }

    @Test("rect standardizes negative dimensions")
    func standardizesNegativeDimensions() {
        let rect = PBRect(x: 100, y: 50, width: -40, height: -20).standardized

        #expect(rect == PBRect(x: 60, y: 30, width: 40, height: 20))
    }

    @Test("rect contains points in standardized coordinates")
    func containsPoints() {
        let rect = PBRect(x: 100, y: 50, width: -40, height: -20)

        #expect(rect.contains(PBPoint(x: 80, y: 40)))
        #expect(!rect.contains(PBPoint(x: 10, y: 40)))
    }

    @Test("rect intersection returns overlapping area")
    func intersection() {
        let lhs = PBRect(x: 0, y: 0, width: 100, height: 100)
        let rhs = PBRect(x: 50, y: 25, width: 100, height: 50)

        #expect(lhs.intersection(rhs) == PBRect(x: 50, y: 25, width: 50, height: 50))
    }

    @Test("rect intersection returns nil for touching edges")
    func touchingEdgesDoNotIntersect() {
        let lhs = PBRect(x: 0, y: 0, width: 100, height: 100)
        let rhs = PBRect(x: 100, y: 0, width: 50, height: 50)

        #expect(lhs.intersection(rhs) == nil)
    }

    @Test("rect inset applies all edges")
    func inset() {
        let rect = PBRect(x: 10, y: 20, width: 100, height: 80)
            .insetBy(PBInsets(top: 5, left: 10, bottom: 15, right: 20))

        #expect(rect == PBRect(x: 20, y: 25, width: 70, height: 60))
    }
}

