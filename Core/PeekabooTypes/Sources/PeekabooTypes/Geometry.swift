/// Platform-neutral 2D point for desktop coordinates.
public struct PBPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Platform-neutral 2D size for desktop geometry.
public struct PBSize: Codable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public var isEmpty: Bool {
        self.width <= 0 || self.height <= 0
    }
}

/// Platform-neutral rectangle in desktop coordinates.
public struct PBRect: Codable, Hashable, Sendable {
    public var origin: PBPoint
    public var size: PBSize

    public init(origin: PBPoint, size: PBSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(
            origin: PBPoint(x: x, y: y),
            size: PBSize(width: width, height: height))
    }

    public var x: Double {
        get { self.origin.x }
        set { self.origin.x = newValue }
    }

    public var y: Double {
        get { self.origin.y }
        set { self.origin.y = newValue }
    }

    public var width: Double {
        get { self.size.width }
        set { self.size.width = newValue }
    }

    public var height: Double {
        get { self.size.height }
        set { self.size.height = newValue }
    }

    public var minX: Double { min(self.x, self.x + self.width) }
    public var minY: Double { min(self.y, self.y + self.height) }
    public var maxX: Double { max(self.x, self.x + self.width) }
    public var maxY: Double { max(self.y, self.y + self.height) }
    public var midX: Double { (self.minX + self.maxX) / 2 }
    public var midY: Double { (self.minY + self.maxY) / 2 }

    public var isEmpty: Bool {
        self.width == 0 || self.height == 0
    }

    public var standardized: PBRect {
        PBRect(
            x: self.minX,
            y: self.minY,
            width: self.maxX - self.minX,
            height: self.maxY - self.minY)
    }

    public var center: PBPoint {
        PBPoint(x: self.midX, y: self.midY)
    }

    public func contains(_ point: PBPoint) -> Bool {
        let rect = self.standardized
        return point.x >= rect.minX &&
            point.x <= rect.maxX &&
            point.y >= rect.minY &&
            point.y <= rect.maxY
    }

    public func intersects(_ other: PBRect) -> Bool {
        let lhs = self.standardized
        let rhs = other.standardized
        return lhs.maxX > rhs.minX &&
            rhs.maxX > lhs.minX &&
            lhs.maxY > rhs.minY &&
            rhs.maxY > lhs.minY
    }

    public func intersection(_ other: PBRect) -> PBRect? {
        guard self.intersects(other) else { return nil }

        let lhs = self.standardized
        let rhs = other.standardized
        let minX = max(lhs.minX, rhs.minX)
        let minY = max(lhs.minY, rhs.minY)
        let maxX = min(lhs.maxX, rhs.maxX)
        let maxY = min(lhs.maxY, rhs.maxY)

        return PBRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public func insetBy(_ insets: PBInsets) -> PBRect {
        PBRect(
            x: self.x + insets.left,
            y: self.y + insets.top,
            width: self.width - insets.left - insets.right,
            height: self.height - insets.top - insets.bottom)
    }
}

/// Platform-neutral edge insets for desktop rectangles.
public struct PBInsets: Codable, Hashable, Sendable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public static let zero = PBInsets(top: 0, left: 0, bottom: 0, right: 0)
}

