import Cocoa

extension SelectionView {
    override func resetCursorRects() {
        super.resetCursorRects()
        if mode == .resizing, let corner = resizingCorner ?? resizingTextAreaCorner {
            addCursorRect(bounds, cursor: resizeCursor(for: corner))
            return
        }
        if mode == .moving || mode == .elementDragging || mode == .dragging {
            addCursorRect(bounds, cursor: .closedHand)
            return
        }
        if mode == .selecting || mode == .drawing {
            addCursorRect(bounds, cursor: .crosshair)
            return
        }
        if let rect = selectedRect {
            if isToolMode {
                addCursorRect(rect, cursor: .crosshair)
            } else if currentTool == .eyedropper {
                addCursorRect(rect, cursor: eyedropperCursor)
            } else if currentTool == .move, activeTextField == nil {
                addCursorRect(rect, cursor: .openHand)
            }
            if activeTextField == nil, currentTool == .move {
                addHandleCursorRects(controlPointHitRects(for: rect))
            }
        }
        if activeTextField != nil, let rect = activeTextRect {
            let hits = controlPointRects(for: rect, size: 8).map { $0.insetBy(dx: -10, dy: -10) }
            addHandleCursorRects(hits)
        }
    }

    /// Edges first, corners last. Later cursor rects win where they overlap,
    /// which keeps a single resize cursor stable across each handle.
    private func addHandleCursorRects(_ hits: [NSRect]) {
        let order = [4, 5, 6, 7, 0, 1, 2, 3]
        for index in order where index < hits.count {
            let hit = hits[index]
            guard hit.width > 2, hit.height > 2 else { continue }
            addCursorRect(hit, cursor: resizeCursor(for: index))
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        switch mode {
        case .resizing, .moving, .elementDragging, .dragging, .selecting:
            applyCursor(at: convert(event.locationInWindow, from: nil))
        default:
            super.cursorUpdate(with: event)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [
            .activeAlways, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    func resizeCursor(for handle: Int) -> NSCursor {
        switch handle {
        case 0, 3:
            return resizeNorthEastSouthWestCursor
        case 1, 2:
            return resizeNorthWestSouthEastCursor
        case 4, 5:
            return .resizeUpDown
        case 6, 7:
            return .resizeLeftRight
        default:
            return .arrow
        }
    }

    func isPointInPopover(_ location: NSPoint) -> Bool {
        let popovers: [NSView?] = [colorPickerView, lineWidthPickerView, fontPickerView, aiPromptView]
        return popovers.contains { $0?.frame.contains(location) == true }
    }

    func applyCursor(at location: NSPoint) {
        if mode == .resizing {
            if let corner = resizingCorner ?? resizingTextAreaCorner {
                resizeCursor(for: corner).set()
                return
            }
        }
        if mode == .moving || mode == .elementDragging || mode == .dragging {
            NSCursor.closedHand.set()
            return
        }
        if mode == .selecting || mode == .drawing || (mode == .creating && startPoint != nil) {
            NSCursor.crosshair.set()
            return
        }
        if isPointInPopover(location) || pointIsOnToolbarControl(location) {
            NSCursor.arrow.set()
            return
        }
        if activeTextField != nil, let rect = activeTextRect,
           let handle = textHandleIndex(at: location, in: rect) {
            resizeCursor(for: handle).set()
            return
        }
        if activeTextField == nil, currentTool == .move, let rect = selectedRect,
           let handle = selectionHandleIndex(at: location, in: rect) {
            resizeCursor(for: handle).set()
            return
        }
        if let toolbar = toolbarView, toolbar.frame.contains(location) {
            NSCursor.arrow.set()
            return
        }
        if currentTool == .eyedropper, let rect = selectedRect, rect.contains(location) {
            eyedropperCursor.set()
            return
        }
        if isDrawingTool, let rect = selectedRect, rect.contains(location) {
            NSCursor.crosshair.set()
            return
        }
        if currentTool == .move, let rect = selectedRect, rect.contains(location) {
            NSCursor.openHand.set()
            return
        }
        NSCursor.arrow.set()
    }

    func applyCursorAtCurrentMouse() {
        guard let window else { return }
        applyCursor(at: convert(window.mouseLocationOutsideOfEventStream, from: nil))
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
