import Cocoa

extension SelectionView {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if control === aiPromptField, commandSelector == #selector(insertNewline(_:)) {
            sendAIPrompt()
            return true
        }
        if control === aiPromptField, commandSelector == #selector(cancelOperation(_:)) {
            if currentTool == .ai {
                currentTool = .move
                updateToolButtonStates()
                hideAIPrompt()
                window?.makeFirstResponder(self)
                needsDisplay = true
            }
            return true
        }
        if control === activeTextField, commandSelector == #selector(insertNewline(_:)) {
            textView.insertNewlineIgnoringFieldEditor(control)
            return true
        }
        if control === activeTextField, commandSelector == #selector(cancelOperation(_:)) {
            finishActiveTextEntry(commit: true)
            window?.makeFirstResponder(self)
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
        if handleCommandShortcut(event) {
            return
        }
        if handleToolShortcut(event) {
            return
        }
        if event.keyCode == 53 { // ESC key
            if currentTool == .ai {
                currentTool = .move
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
        } else {
            super.keyDown(with: event)
        }
    }

    private func handleCommandShortcut(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let key = event.charactersIgnoringModifiers?.lowercased()
        else {
            return false
        }
        switch key {
        case "c":
            copyToClipboard()
            return true
        case "s":
            saveImage()
            return true
        case "z":
            undoLastDrawing()
            return true
        default:
            return false
        }
    }

    private func handleToolShortcut(_ event: NSEvent) -> Bool {
        let disallowed: NSEvent.ModifierFlags = [.command, .option, .control, .function]
        if !event.modifierFlags.intersection(disallowed).isEmpty {
            return false
        }
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
        let tool: ToolMode?
        switch key {
        case "v":
            tool = .move
        case "m":
            tool = .select
        case "p":
            tool = .pen
        case "l":
            tool = .line
        case "w":
            tool = .arrow
        case "r":
            tool = .rectangle
        case "c":
            tool = .ellipse
        case "t":
            tool = .text
        case "a":
            tool = .ai
        case "e":
            tool = .eraser
        default:
            tool = nil
        }
        guard let nextTool = tool else { return false }
        activateTool(nextTool)
        return true
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

        if activeTextField != nil, let textRect = activeTextRect,
           let index = textHandleIndex(at: location, in: textRect) {
            window?.makeFirstResponder(self)
            mode = .resizing
            resizingTextAreaCorner = index
            resizingCorner = nil
            resizeGrabOffset = grabOffsetForResize(corner: index, at: location, in: textRect)
            window?.invalidateCursorRects(for: self)
            return
        }

        if activeTextField == nil, currentTool == .move, let rect = selectedRect,
           let index = selectionHandleIndex(at: location, in: rect),
           !pointIsOnToolbarControl(location) {
            mode = .resizing
            resizingCorner = index
            resizingTextAreaCorner = nil
            resizeGrabOffset = grabOffsetForResize(corner: index, at: location, in: rect)
            window?.invalidateCursorRects(for: self)
            return
        }

        if let toolbar = toolbarView, toolbar.frame.contains(location) {
            return
        }

        if currentTool == .ai, aiIsSelectingEditRect {
            aiEditStartPoint = clampedPoint(location)
            aiEditCurrentPoint = aiEditStartPoint
            aiEditRect = nil
            needsDisplay = true
            return
        }

        if currentTool == .text {
            if let rect = selectedRect, rect.contains(location) {
                if let activeRect = activeTextRect, activeRect.contains(location) {
                    window?.makeFirstResponder(activeTextField)
                    return
                }
                if activeTextField != nil {
                    finishActiveTextEntry(commit: true)
                }
                if let index = drawingElements.lastIndex(where: { element in
                    guard case .text = element.type else { return false }
                    return elementHitTest(element, point: location, tolerance: 4)
                }) {
                    startTextEdit(for: drawingElements[index], at: index)
                    return
                }
                let start = clampedPoint(location, to: rect)
                textAreaDragStart = start
                textAreaDragCurrent = start
                mode = .creating
                needsDisplay = true
                return
            }
        }

        // If editing text, clicking outside the text area should just finish editing.
        if mode == .editing,
           editingTextElementIndex != nil,
           let _ = activeTextField,
           let rect = activeTextRect,
           !rect.contains(location) {
            finishActiveTextEntry(commit: true)
        }
        
        // Check if clicking inside selected region
        if let rect = selectedRect, rect.contains(location) {
            if event.clickCount == 2,
                let index = drawingElements.lastIndex(where: { elementHitTest($0, point: location, tolerance: 6) }) {
                let element = drawingElements[index]
                if case .text = element.type {
                    startTextEdit(for: element, at: index)
                    return
                }
            }
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
                currentTool = .move
                updateToolButtonStates()
                window?.invalidateCursorRects(for: self)
                needsDisplay = true
                return
            }
            if currentTool == .select {
                if let index = drawingElements.lastIndex(where: { elementHitTest($0, point: location, tolerance: 6) }) {
                    selectedElementIndex = index
                    mode = .elementDragging
                    lastDragPoint = location
                    window?.invalidateCursorRects(for: self)
                    needsDisplay = true
                    return
                }
                selectedElementIndex = nil
                needsDisplay = true
                return
            }
            if isToolMode {
                // Start drawing
                mode = .drawing
                drawingStartPoint = location
                currentDrawingPoints = [location]
                window?.invalidateCursorRects(for: self)
            } else if currentTool == .move {
                // Start dragging only in move mode.
                selectedElementIndex = nil
                mode = .moving
                dragOffset = NSPoint(x: location.x - rect.origin.x, y: location.y - rect.origin.y)
                window?.invalidateCursorRects(for: self)
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
        activeTextRect = nil
        aiResultImage = nil
        aiEditRect = nil
        aiIsSelectingEditRect = false
        
        clearToolbar()
        notifySelectionChanged()
        window?.invalidateCursorRects(for: self)
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        defer {
            applyCursor(at: location)
            updateSizeLabelHover(at: location)
        }
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
            
        case .moving:
            if let last = lastDragPoint, let index = selectedElementIndex {
                let delta = NSPoint(x: location.x - last.x, y: location.y - last.y)
                translateDrawingElement(at: index, by: delta)
                lastDragPoint = location
                needsDisplay = true
            } else {
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
            }
            
        case .resizing:
            let grabbed = NSPoint(
                x: location.x - resizeGrabOffset.x,
                y: location.y - resizeGrabOffset.y
            )
            if let corner = resizingCorner {
                handleResize(corner: corner, to: clampedPoint(grabbed))
                updateToolbar()
                needsDisplay = true
            } else if let corner = resizingTextAreaCorner, var textRect = activeTextRect {
                let point = clampedPoint(grabbed, to: selectedRect ?? bounds)
                handleTextAreaResize(corner: corner, to: point, rect: &textRect)
                activeTextRect = textRect
                activeTextField?.frame = textRect
                updateTextControlPoints()
                needsDisplay = true
            }
            
        case .creating:
            guard currentTool == .text, let rect = selectedRect else { break }
            textAreaDragCurrent = clampedPoint(location, to: rect)
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
        let location = convert(event.locationInWindow, from: nil)
        defer {
            resizeGrabOffset = .zero
            window?.invalidateCursorRects(for: self)
            updateToolbarHover(at: location, animated: true)
        }
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
                mode = .creating
                if clampedRect.width <= 0 || clampedRect.height <= 0 {
                    closeOverlay()
                    return
                }
            }
            needsDisplay = true
            
        case .moving, .dragging:
            mode = .selected
            lastDragPoint = nil

        case .creating:
            guard currentTool == .text else { break }
            let container = selectedRect ?? bounds
            let box: NSRect
            if let start = textAreaDragStart, let current = textAreaDragCurrent {
                let dragged = normalizedRect(from: start, to: current).intersection(container)
                if dragged.width >= 12, dragged.height >= 12 {
                    box = dragged
                } else {
                    box = defaultTextRect(at: start, in: container)
                }
            } else {
                box = defaultTextRect(at: location, in: container)
            }
            textAreaDragStart = nil
            textAreaDragCurrent = nil
            startTextEntry(in: box)
            needsDisplay = true

        case .resizing:
            let resumeTextEdit = resizingTextAreaCorner != nil
            mode = activeTextField == nil ? .selected : .editing
            resizingCorner = nil
            resizingTextAreaCorner = nil
            if resumeTextEdit, let field = activeTextField {
                window?.makeFirstResponder(field)
            }
            
        case .drawing:
            finishDrawing()
            mode = .selected
            currentDrawingPoints = []
            drawingStartPoint = nil
            needsDisplay = true
            
        case .elementDragging:
            mode = .selected
            lastDragPoint = nil
            
        default:
            break
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        updateToolbarHover(at: location, animated: true)
        if currentTool == .eraser, let rect = selectedRect, rect.contains(location) {
            let nextHover = drawingElements.lastIndex(where: { elementHitTest($0, point: location, tolerance: 6) })
            if nextHover != hoverEraserIndex {
                hoverEraserIndex = nextHover
                needsDisplay = true
            }
        } else if hoverEraserIndex != nil {
            hoverEraserIndex = nil
            needsDisplay = true
        }
        super.mouseMoved(with: event)
    }

    override func mouseEntered(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        updateToolbarHover(at: location, animated: true)
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        updateToolbarHover(at: nil, animated: true)
        NSCursor.arrow.set()
        super.mouseExited(with: event)
    }
}
