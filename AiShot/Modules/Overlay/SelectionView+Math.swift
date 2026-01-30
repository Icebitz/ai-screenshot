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

    func controlPointRects(for rect: NSRect) -> [NSRect] {
        let size: CGFloat = 8
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
