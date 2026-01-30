import Cocoa

extension SelectionView {
    override func resetCursorRects() {
        super.resetCursorRects()
        if let rect = selectedRect {
            if isDrawingTool {
                addCursorRect(rect, cursor: .crosshair)
                return
            }
            if currentTool == .eyedropper {
                addCursorRect(rect, cursor: eyedropperCursor)
                return
            }
            if currentTool == .move {
                addCursorRect(rect, cursor: .openHand)
            }
        }
        for (index, rect) in controlPoints.enumerated() {
            let cursor: NSCursor
            switch index {
            case 4, 5:
                cursor = .resizeUpDown
            case 6, 7:
                cursor = .resizeLeftRight
            default:
                cursor = .crosshair
            }
            addCursorRect(rect.insetBy(dx: -4, dy: -4), cursor: cursor)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    func makeEyedropperCursor() -> NSCursor {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: size).fill()
        if let symbol = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: nil) {
            symbol.isTemplate = true
            NSColor.white.set()
            symbol.draw(in: NSRect(origin: .zero, size: size))
            NSColor.black.withAlphaComponent(0.9).set()
            symbol.draw(in: NSRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4))
        }
        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: 2, y: 2))
    }
}
