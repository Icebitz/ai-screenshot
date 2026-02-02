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
        } else if event.keyCode == 51 || event.keyCode == 117 { // Delete or Forward Delete
            if let index = selectedElementIndex, index >= 0, index < drawingElements.count {
                drawingElements.remove(at: index)
                selectedElementIndex = nil
                hoverEraserIndex = nil
                needsDisplay = true
            } else {
                super.keyDown(with: event)
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
        
        // Check if clicking on text area control points when editing
        if activeTextField != nil, let _ = activeTextRect {
            let hitAreaExpansion: CGFloat = 8
            for (index, controlPoint) in textControlPoints.enumerated() {
                if controlPoint.insetBy(dx: -hitAreaExpansion, dy: -hitAreaExpansion).contains(location) {
                    window?.makeFirstResponder(self)
                    mode = .resizingTextArea
                    resizingTextAreaCorner = index
                    return
                }
            }
        }
        
        // Check if clicking on control points for resizing selection
        if activeTextField == nil, let _ = selectedRect {
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
                textAreaDragStart = location
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
                    mode = .movingElement
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
                // Start dragging only in move mode.
                selectedElementIndex = nil
                mode = .moving
                dragOffset = NSPoint(x: location.x - rect.origin.x, y: location.y - rect.origin.y)
            }
            return
        }
        
        // Start new selection (clear previous) - but not if clicking on text control points
        if activeTextField != nil, let _ = activeTextRect {
            let hitAreaExpansion: CGFloat = 8
            for (index, controlPoint) in textControlPoints.enumerated() {
                if controlPoint.insetBy(dx: -hitAreaExpansion, dy: -hitAreaExpansion).contains(location) {
                    window?.makeFirstResponder(self)
                    mode = .resizingTextArea
                    resizingTextAreaCorner = index
                    return
                }
            }
        }
        if activeTextField != nil {
            finishActiveTextEntry(commit: true)
        }
        mode = .creating
        startPoint = clampedPoint(location)
        currentPoint = clampedPoint(location)
        selectedRect = nil
        drawingElements.removeAll()
        selectedElementIndex = nil
        hoverEraserIndex = nil
        currentTool = .none
        textAreaDragStart = nil
        activeTextField?.removeFromSuperview()
        activeTextField = nil
        activeTextRect = nil
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
        // Handle text area drag to define
        if textAreaDragStart != nil {
            let start = textAreaDragStart!
            if mode == .creatingText {
                currentPoint = clampedPoint(location)
            } else {
                let dist = hypot(location.x - start.x, location.y - start.y)
                if dist > 4 {
                    mode = .creatingText
                    startPoint = start
                    currentPoint = clampedPoint(location)
                }
            }
            needsDisplay = true
            return
        }
        
        switch mode {
        case .creating:
            currentPoint = clampedPoint(location)
            needsDisplay = true
            
        case .creatingText:
            currentPoint = clampedPoint(location)
            needsDisplay = true
            
        case .moving:
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
            
        case .resizingTextArea:
            guard let corner = resizingTextAreaCorner, var rect = activeTextRect else { return }
            handleTextAreaResize(corner: corner, to: clampedPoint(location), rect: &rect)
            activeTextRect = rect
            activeTextField?.frame = rect
            updateTextControlPoints()
            needsDisplay = true
            
        case .drawing:
            if let rect = selectedRect {
                let clamped = clampedPoint(location, to: rect)
                currentDrawingPoints.append(clamped)
            } else {
                currentDrawingPoints.append(location)
            }
            needsDisplay = true
            
        case .movingElement:
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
        // Handle text area resize end
        if mode == .resizingTextArea {
            mode = .active
            resizingTextAreaCorner = nil
            return
        }
        
        // Handle text tool: click = default size, drag = defined rect
        if textAreaDragStart != nil {
            defer { textAreaDragStart = nil }
            if mode == .creatingText, let start = startPoint, let current = currentPoint, let sel = selectedRect {
                let rect = normalizedRect(from: start, to: current)
                let clamped = rect.intersection(sel).intersection(bounds)
                if clamped.width >= textAreaMinWidth, clamped.height >= textAreaMinHeight {
                    startTextEntry(in: clamped)
                }
            } else {
                startTextEntry(at: textAreaDragStart!)
            }
            mode = .active
            needsDisplay = true
            return
        }
        
        switch mode {
        case .creating:
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
                mode = .active
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
            
        case .moving:
            mode = .active
            NSCursor.openHand.set()
            
        case .resizing:
            mode = .active
            resizingCorner = nil
            
        case .drawing:
            finishDrawing()
            mode = .active
            currentDrawingPoints = []
            drawingStartPoint = nil
            needsDisplay = true
            
        case .movingElement:
            mode = .active
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
           mode != .moving, mode != .resizing, mode != .movingElement, mode != .resizingTextArea {
            eyedropperCursor.set()
        }
        if isDrawingTool, let rect = selectedRect, rect.contains(location),
           mode != .moving, mode != .resizing, mode != .movingElement, mode != .resizingTextArea {
            NSCursor.crosshair.set()
        }
        if currentTool == .move, let rect = selectedRect, rect.contains(location), mode != .moving, mode != .movingElement, mode != .resizingTextArea {
            NSCursor.openHand.set()
        }
        super.mouseMoved(with: event)
    }
}
