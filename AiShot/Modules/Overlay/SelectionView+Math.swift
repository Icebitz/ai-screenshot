import Cocoa

extension SelectionView {
    func normalizedRect(from start: NSPoint, to end: NSPoint) -> NSRect {
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        
        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    func clampedPoint(_ point: NSPoint) -> NSPoint {
        let x = min(max(bounds.minX, point.x), bounds.maxX)
        let y = min(max(bounds.minY, point.y), bounds.maxY)
        return NSPoint(x: x, y: y)
    }

    func clampedPoint(_ point: NSPoint, to rect: NSRect) -> NSPoint {
        let x = min(max(rect.minX, point.x), rect.maxX)
        let y = min(max(rect.minY, point.y), rect.maxY)
        return NSPoint(x: x, y: y)
    }

    func imageRectForViewRect(_ rect: NSRect) -> CGRect {
        let scaleX = CGFloat(screenImage.width) / bounds.width
        let scaleY = CGFloat(screenImage.height) / bounds.height
        let flippedY = bounds.height - rect.maxY
        var imageRect = CGRect(
            x: rect.minX * scaleX,
            y: flippedY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        imageRect = imageRect.integral
        let maxX = CGFloat(screenImage.width)
        let maxY = CGFloat(screenImage.height)
        imageRect.origin.x = max(0, min(imageRect.origin.x, maxX))
        imageRect.origin.y = max(0, min(imageRect.origin.y, maxY))
        imageRect.size.width = max(0, min(imageRect.size.width, maxX - imageRect.origin.x))
        imageRect.size.height = max(0, min(imageRect.size.height, maxY - imageRect.origin.y))
        return imageRect
    }

    func controlPointRects(for rect: NSRect, size: CGFloat = 12) -> [NSRect] {
        let half = size / 2
        return [
            NSRect(x: rect.minX - half, y: rect.minY - half, width: size, height: size), // Bottom-left
            NSRect(x: rect.maxX - half, y: rect.minY - half, width: size, height: size), // Bottom-right
            NSRect(x: rect.minX - half, y: rect.maxY - half, width: size, height: size), // Top-left
            NSRect(x: rect.maxX - half, y: rect.maxY - half, width: size, height: size), // Top-right
            NSRect(x: rect.midX - half, y: rect.minY - half, width: size, height: size), // Bottom-mid
            NSRect(x: rect.midX - half, y: rect.maxY - half, width: size, height: size), // Top-mid
            NSRect(x: rect.minX - half, y: rect.midY - half, width: size, height: size), // Left-mid
            NSRect(x: rect.maxX - half, y: rect.midY - half, width: size, height: size)  // Right-mid
        ]
    }

    /// Grab zones for the eight handles. Corners stay out of the edge bands so the
    /// pointer does not flip between diagonal and edge cursors on one handle.
    /// Top and bottom bands are much taller than the drawn grip.
    /// Index order matches `controlPointRects`.
    func controlPointHitRects(for rect: NSRect) -> [NSRect] {
        let cornerSize: CGFloat = 28
        let verticalReach: CGFloat = 32
        let horizontalReach: CGFloat = 22
        let innerV = min(verticalReach, max(0, rect.height / 2 - 10))
        let innerH = min(horizontalReach, max(0, rect.width / 2 - 10))
        let edgeWidth = max(0, rect.width - cornerSize)
        let edgeHeight = max(0, rect.height - cornerSize)
        let inset = cornerSize / 2

        func corner(_ x: CGFloat, _ y: CGFloat) -> NSRect {
            NSRect(x: x - cornerSize / 2, y: y - cornerSize / 2, width: cornerSize, height: cornerSize)
        }

        let bottom = NSRect(
            x: rect.minX + inset,
            y: rect.minY - verticalReach,
            width: edgeWidth,
            height: innerV + verticalReach
        )
        let top = NSRect(
            x: rect.minX + inset,
            y: rect.maxY - innerV,
            width: edgeWidth,
            height: innerV + verticalReach
        )
        let left = NSRect(
            x: rect.minX - horizontalReach,
            y: rect.minY + inset,
            width: innerH + horizontalReach,
            height: edgeHeight
        )
        let right = NSRect(
            x: rect.maxX - innerH,
            y: rect.minY + inset,
            width: innerH + horizontalReach,
            height: edgeHeight
        )
        return [
            corner(rect.minX, rect.minY),
            corner(rect.maxX, rect.minY),
            corner(rect.minX, rect.maxY),
            corner(rect.maxX, rect.maxY),
            bottom,
            top,
            left,
            right
        ]
    }

    /// Distance from the pointer to the edge it grabbed, so a large hit zone
    /// does not jump the selection onto the cursor on the first drag.
    func grabOffsetForResize(corner: Int, at point: NSPoint, in rect: NSRect) -> CGPoint {
        switch corner {
        case 0:
            return CGPoint(x: point.x - rect.minX, y: point.y - rect.minY)
        case 1:
            return CGPoint(x: point.x - rect.maxX, y: point.y - rect.minY)
        case 2:
            return CGPoint(x: point.x - rect.minX, y: point.y - rect.maxY)
        case 3:
            return CGPoint(x: point.x - rect.maxX, y: point.y - rect.maxY)
        case 4:
            return CGPoint(x: 0, y: point.y - rect.minY)
        case 5:
            return CGPoint(x: 0, y: point.y - rect.maxY)
        case 6:
            return CGPoint(x: point.x - rect.minX, y: 0)
        case 7:
            return CGPoint(x: point.x - rect.maxX, y: 0)
        default:
            return .zero
        }
    }

    func selectionHandleIndex(at point: NSPoint, in rect: NSRect) -> Int? {
        let hits = controlPointHitRects(for: rect)
        for index in 0..<min(4, hits.count) where hits[index].contains(point) {
            return index
        }
        for index in 4..<hits.count where hits[index].width > 2 && hits[index].height > 2 && hits[index].contains(point) {
            return index
        }
        return nil
    }

    func textHandleIndex(at point: NSPoint, in rect: NSRect) -> Int? {
        let hits = controlPointRects(for: rect, size: 8).map { $0.insetBy(dx: -10, dy: -10) }
        for (index, hit) in hits.enumerated() where hit.contains(point) {
            return index
        }
        return nil
    }

    func polylineHitTest(points: [NSPoint], point: NSPoint, tolerance: CGFloat) -> Bool {
        guard points.count > 1 else { return false }
        for idx in 0..<(points.count - 1) {
            if distanceToSegment(point, points[idx], points[idx + 1]) <= tolerance {
                return true
            }
        }
        return false
    }

    func rectEdgeHitTest(_ rect: NSRect, point: NSPoint, tolerance: CGFloat) -> Bool {
        let topLeft = NSPoint(x: rect.minX, y: rect.maxY)
        let topRight = NSPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = NSPoint(x: rect.minX, y: rect.minY)
        let bottomRight = NSPoint(x: rect.maxX, y: rect.minY)
        return distanceToSegment(point, topLeft, topRight) <= tolerance ||
            distanceToSegment(point, topRight, bottomRight) <= tolerance ||
            distanceToSegment(point, bottomRight, bottomLeft) <= tolerance ||
            distanceToSegment(point, bottomLeft, topLeft) <= tolerance
    }

    func ellipseEdgeHitTest(_ rect: NSRect, point: NSPoint, tolerance: CGFloat) -> Bool {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2
        let ry = rect.height / 2
        guard rx > 0, ry > 0 else { return false }
        let dx = point.x - center.x
        let dy = point.y - center.y
        let normalized = sqrt((dx * dx) / (rx * rx) + (dy * dy) / (ry * ry))
        return abs(normalized - 1) <= (tolerance / max(rx, ry))
    }

    func ellipseContainsPoint(_ rect: NSRect, point: NSPoint) -> Bool {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2
        let ry = rect.height / 2
        guard rx > 0, ry > 0 else { return false }
        let dx = point.x - center.x
        let dy = point.y - center.y
        let normalized = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry)
        return normalized <= 1
    }

    func elementBoundingRect(_ element: DrawingElement) -> NSRect? {
        switch element.type {
        case .pen(let points):
            guard let first = points.first else { return nil }
            var minX = first.x
            var minY = first.y
            var maxX = first.x
            var maxY = first.y
            for point in points.dropFirst() {
                minX = min(minX, point.x)
                minY = min(minY, point.y)
                maxX = max(maxX, point.x)
                maxY = max(maxY, point.y)
            }
            return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        case .line(let start, let end), .arrow(let start, let end):
            let minX = min(start.x, end.x)
            let minY = min(start.y, end.y)
            let maxX = max(start.x, end.x)
            let maxY = max(start.y, end.y)
            return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        case .rectangle(let rect), .ellipse(let rect):
            return rect
        case .text(_, let rect):
            return rect
        }
    }

    func distanceToSegment(_ p: NSPoint, _ a: NSPoint, _ b: NSPoint) -> CGFloat {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let apx = p.x - a.x
        let apy = p.y - a.y
        let abLenSq = abx * abx + aby * aby
        if abLenSq == 0 {
            return hypot(apx, apy)
        }
        let t = max(0, min(1, (apx * abx + apy * aby) / abLenSq))
        let closest = NSPoint(x: a.x + abx * t, y: a.y + aby * t)
        return hypot(p.x - closest.x, p.y - closest.y)
    }
}
