import Cocoa

extension SelectionView {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if control === aiPromptField, commandSelector == #selector(insertNewline(_:)) {
            sendAIPrompt()
            return true
        }
        if control === aiPromptField, commandSelector == #selector(cancelOperation(_:)) {
            if currentTool == .ai {
                currentTool = .none
                updateToolButtonStates()
                hideAIPrompt()
                window?.makeFirstResponder(self)
                needsDisplay = true
            }
            return true
        }
        return false
    }

    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField, field === aiPromptField {
            updateSendState()
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            if currentTool == .ai {
                currentTool = .none
                updateToolButtonStates()
                hideAIPrompt()
                window?.makeFirstResponder(self)
                needsDisplay = true
            } else {
                closeOverlay()
            }
        } else if event.modifierFlags.contains(.command),
                  event.charactersIgnoringModifiers?.lowercased() == "z" {
            undoLastDrawing()
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        let pickerViews: [NSView?] = [colorPickerView, lineWidthPickerView, fontPickerView, aiPromptView]
        if pickerViews.contains(where: { $0?.frame.contains(location) == true }) {
            return
        }
        if pickerViews.contains(where: { $0 != nil }) {
            hideColorPicker()
            hideLineWidthPicker()
            hideFontPicker()
        }

        if let toolbar = toolbarView, toolbar.frame.contains(location) {
            let localPoint = toolbar.convert(location, from: self)
            let hitView = toolbar.hitTest(localPoint)
            if let control = hitView as? NSControl, control.isEnabled {
                // Let controls handle the event.
            } else {
                return
            }
        }

        if currentTool == .ai, aiIsSelectingEditRect {
            aiEditStartPoint = clampedPoint(location)
            aiEditCurrentPoint = aiEditStartPoint
            aiEditRect = nil
            needsDisplay = true
            return
        }
        
        // Check if clicking on control points for resizing
        if currentTool == .move, let _ = selectedRect {
            for (index, controlPoint) in controlPoints.enumerated() {
                if controlPoint.contains(location) {
                    mode = .resizing
                    resizingCorner = index
                    return
                }
            }
        }
        
        // Check if clicking inside selected region
        if let rect = selectedRect, rect.contains(location) {
            if currentTool == .text {
                startTextEntry(at: location)
                return
            }
            if currentTool == .eraser {
                eraseElement(at: location)
                return
            }
            if currentTool == .eyedropper {
                if let picked = colorAtViewPoint(location) {
                    switch activeColorTarget {
                    case .stroke:
                        currentStrokeColor = picked
                        strokeColorButton?.swatchColor = picked
                    case .fill:
                        currentFillColor = picked
                        fillColorButton?.swatchColor = picked
                    }
                }
                currentTool = .none
                updateToolButtonStates()
                NSCursor.arrow.set()
                window?.invalidateCursorRects(for: self)
                needsDisplay = true
                return
            }
            if currentTool == .none {
                if let index = drawingElements.lastIndex(where: { elementHitTest($0, point: location, tolerance: 6) }) {
                    selectedElementIndex = index
                    mode = .elementDragging
                    lastDragPoint = location
                    needsDisplay = true
                    return
                }
                selectedElementIndex = nil
                needsDisplay = true
                return
            }
            if isDrawingTool {
                // Start drawing
                mode = .drawing
                drawingStartPoint = location
                currentDrawingPoints = [location]
            } else if currentTool == .move {
                // Start dragging
                selectedElementIndex = nil
                mode = .dragging
                dragOffset = NSPoint(x: location.x - rect.origin.x, y: location.y - rect.origin.y)
            }
            return
        }
        
        // Start new selection (clear previous)
        mode = .selecting
        startPoint = clampedPoint(location)
        currentPoint = clampedPoint(location)
        selectedRect = nil
        drawingElements.removeAll()
        selectedElementIndex = nil
        hoverEraserIndex = nil
        currentTool = .none
        activeTextField?.removeFromSuperview()
        activeTextField = nil
        activeTextOrigin = nil
        aiResultImage = nil
        aiEditRect = nil
        aiIsSelectingEditRect = false
        
        clearToolbar()
        notifySelectionChanged()
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if aiIsSelectingEditRect, let start = aiEditStartPoint {
            let current = clampedPoint(location)
            aiEditCurrentPoint = current
            aiEditRect = normalizedRect(from: start, to: current)
            needsDisplay = true
            return
        }
        switch mode {
        case .selecting:
            currentPoint = clampedPoint(location)
            needsDisplay = true
            
        case .dragging:
            NSCursor.closedHand.set()
            guard var rect = selectedRect else { return }
            let oldOrigin = rect.origin
            rect.origin = NSPoint(x: location.x - dragOffset.x, y: location.y - dragOffset.y)
            rect.origin.x = min(max(bounds.minX, rect.origin.x), bounds.maxX - rect.width)
            rect.origin.y = min(max(bounds.minY, rect.origin.y), bounds.maxY - rect.height)
            selectedRect = rect
            let delta = NSPoint(x: rect.origin.x - oldOrigin.x, y: rect.origin.y - oldOrigin.y)
            if delta.x != 0 || delta.y != 0 {
                translateDrawingElements(by: delta)
            }
            updateControlPoints()
            updateToolbar()
            needsDisplay = true
            
        case .resizing:
            guard let corner = resizingCorner else { return }
            handleResize(corner: corner, to: clampedPoint(location))
            updateToolbar()
            needsDisplay = true
            
        case .drawing:
            if let rect = selectedRect {
                let clamped = clampedPoint(location, to: rect)
                currentDrawingPoints.append(clamped)
            } else {
                currentDrawingPoints.append(location)
            }
            needsDisplay = true
            
        case .elementDragging:
            NSCursor.closedHand.set()
            if let last = lastDragPoint, let index = selectedElementIndex {
                let delta = NSPoint(x: location.x - last.x, y: location.y - last.y)
                translateDrawingElement(at: index, by: delta)
                lastDragPoint = location
                needsDisplay = true
            }
            
        default:
            break
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if aiIsSelectingEditRect {
            defer {
                aiIsSelectingEditRect = false
                aiEditStartPoint = nil
                aiEditCurrentPoint = nil
                needsDisplay = true
            }
            guard let start = aiEditStartPoint,
                  let current = aiEditCurrentPoint else {
                aiEditRect = nil
                return
            }
            let rect = normalizedRect(from: start, to: current).intersection(bounds)
            if rect.width > 6 && rect.height > 6 {
                aiEditRect = rect
            } else {
                aiEditRect = nil
            }
            return
        }
        switch mode {
        case .selecting:
            guard let start = startPoint, let current = currentPoint else { return }
            
            let minX = min(start.x, current.x)
            let maxX = max(start.x, current.x)
            let minY = min(start.y, current.y)
            let maxY = max(start.y, current.y)
            
            let rect = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            let clampedRect = rect.intersection(bounds)
            
            if clampedRect.width > 10 && clampedRect.height > 10 {
                selectedRect = clampedRect
                aiEditRect = nil
                aiResultImage = nil
                mode = .selected
                currentTool = .move
                updateControlPoints()
                setupToolbar(for: clampedRect)
                notifySelectionChanged()
                updateToolButtonStates()
            } else {
                startPoint = nil
                currentPoint = nil
                if clampedRect.width <= 0 || clampedRect.height <= 0 {
                    closeOverlay()
                    return
                }
            }
            needsDisplay = true
            
        case .dragging:
            mode = .selected
            NSCursor.openHand.set()
            
        case .resizing:
            mode = .selected
            resizingCorner = nil
            
        case .drawing:
            finishDrawing()
            mode = .selected
            currentDrawingPoints = []
            drawingStartPoint = nil
            needsDisplay = true
            
        case .elementDragging:
            mode = .selected
            lastDragPoint = nil
            NSCursor.openHand.set()
            
        default:
            break
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let pickerViews: [NSView?] = [colorPickerView, lineWidthPickerView, fontPickerView, aiPromptView]
        if pickerViews.contains(where: { $0?.frame.contains(location) == true }) {
            NSCursor.arrow.set()
            super.mouseMoved(with: event)
            return
        }
        if let toolbar = toolbarView, toolbar.frame.contains(location) {
            NSCursor.arrow.set()
            super.mouseMoved(with: event)
            return
        }
        if currentTool == .eraser, let rect = selectedRect, rect.contains(location) {
            hoverEraserIndex = drawingElements.lastIndex(where: { elementHitTest($0, point: location, tolerance: 6) })
            needsDisplay = true
        } else if hoverEraserIndex != nil {
            hoverEraserIndex = nil
            needsDisplay = true
        }
        if currentTool == .eyedropper, let rect = selectedRect, rect.contains(location),
           mode != .dragging, mode != .resizing, mode != .elementDragging {
            eyedropperCursor.set()
        }
        if isDrawingTool, let rect = selectedRect, rect.contains(location),
           mode != .dragging, mode != .resizing, mode != .elementDragging {
            NSCursor.crosshair.set()
        }
        if currentTool == .move, let rect = selectedRect, rect.contains(location), mode != .dragging, mode != .elementDragging {
            NSCursor.openHand.set()
        }
        super.mouseMoved(with: event)
    }
}
