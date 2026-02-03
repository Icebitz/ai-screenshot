import Cocoa

extension SelectionView {
    override func resetCursorRects() {
        super.resetCursorRects()
        if let rect = selectedRect {
            if isToolMode {
                addCursorRect(rect, cursor: .crosshair)
            }
            if currentTool == .eyedropper {
                addCursorRect(rect, cursor: eyedropperCursor)
            }
            if currentTool == .move {
                addCursorRect(rect, cursor: .openHand)
            }
        }
        let pointsToUse = activeTextField != nil ? textControlPoints : controlPoints
        for (index, rect) in pointsToUse.enumerated() {
            let cursor: NSCursor
            switch index {
            case 0, 3:
                cursor = resizeNorthEastSouthWestCursor
            case 1, 2:
                cursor = resizeNorthWestSouthEastCursor
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

    func makeSystemResizeCursor(resource: String, fallback: NSCursor) -> NSCursor {
        let basePath = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Resources/cursors"
        let folderPath = "\(basePath)/\(resource)"
        let imagePath = "\(folderPath)/cursor.pdf"
        let plistPath = "\(folderPath)/info.plist"
        guard
            let image = NSImage(contentsOfFile: imagePath),
            let plist = NSDictionary(contentsOfFile: plistPath),
            let hotX = plist["hotx"] as? NSNumber,
            let hotY = plist["hoty"] as? NSNumber
        else {
            return fallback
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: hotX.doubleValue, y: hotY.doubleValue))
    }
}
