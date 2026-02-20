import Cocoa
import UniformTypeIdentifiers
import UserNotifications

class SelectionView: NSView, NSTextFieldDelegate {
    let screenImage: CGImage
    let overlayId: UUID
    weak var overlayWindow: OverlayWindow?
    
    // Selection state
    var mode: ActionMode = .creating
    var startPoint: NSPoint?
    var currentPoint: NSPoint?
    var selectedRect: NSRect?
    
    // Resizing/dragging
    var controlPoints: [NSRect] = []
    var dragOffset: NSPoint = .zero
    var resizingCorner: Int? = nil
    var lastDragPoint: NSPoint?
    
    // Drawing
    var currentTool: ToolMode = .move
    var currentStrokeColor: NSColor = .red
    var currentFillColor: NSColor? = nil
    var currentLineWidth: CGFloat = 3.0
    var drawingElements: [DrawingElement] = []
    var currentDrawingPoints: [NSPoint] = []
    var drawingStartPoint: NSPoint?
    var currentFontSize: CGFloat = 16
    var currentFontName: String = NSFont.systemFont(ofSize: 16).fontName
    var activeTextField: NSTextField?
    var activeTextRect: NSRect?
    var textAreaDragStart: NSPoint?
    var textAreaDragCurrent: NSPoint?
    var textControlPoints: [NSRect] = []
    var resizingTextAreaCorner: Int?
    var editingTextElementIndex: Int?
    var editingTextOriginalElement: DrawingElement?
    let textAreaDefaultWidth: CGFloat = 200
    let textAreaMinWidth: CGFloat = 40
    let textAreaDefaultHeight: CGFloat = 60
    let textAreaMinHeight: CGFloat = 24
    var isFinishingTextEntry: Bool = false
    var isDeferringTextFinishForResize: Bool = false
    var selectedElementIndex: Int?
    var hoverEraserIndex: Int?
    var trackingArea: NSTrackingArea?
    lazy var eyedropperCursor: NSCursor = makeEyedropperCursor()
    lazy var resizeNorthEastSouthWestCursor: NSCursor = makeSystemResizeCursor(
        resource: "resizenortheastsouthwest",
        fallback: .crosshair
    )
    lazy var resizeNorthWestSouthEastCursor: NSCursor = makeSystemResizeCursor(
        resource: "resizenorthwestsoutheast",
        fallback: .crosshair
    )
    
    // UI Elements
    var toolButtons: [ToolbarButton] = []
    var toolButtonTypes: [ToolMode] = []
    var actionButtons: [ToolbarButton] = []
    var toolbarView: NSVisualEffectView?
    var separatorViews: [NSView] = []
    var groupBorderViews: [NSView] = []
    var strokeColorButton: ColorSwatchButton?
    var fillColorButton: ColorSwatchButton?
    var lineWidthButton: ToolbarButton?
    var fontSettingsButton: ToolbarButton?
    var colorPickerView: NSView?
    var lineWidthPickerView: NSView?
    var fontPickerView: NSView?
    var aiPromptView: NSVisualEffectView?
    var aiPromptField: NSTextField?
    var aiSendButton: ToolbarButton?
    var aiSendSpinner: NSProgressIndicator?
    var aiIsSendingPrompt: Bool = false {
        didSet {
            if aiIsSendingPrompt {
                startAIDashAnimation()
            } else {
                stopAIDashAnimation()
            }
        }
    }
    var aiResultImage: CGImage?
    var aiEditRect: NSRect?
    var aiEditStartPoint: NSPoint?
    var aiEditCurrentPoint: NSPoint?
    var aiIsSelectingEditRect: Bool = false
    var activeColorTarget: ColorTarget = .stroke

    let toolButtonWidth: CGFloat = 32
    let actionButtonWidth: CGFloat = 32
    let toolbarPadding: CGFloat = 10
    let buttonSpacing: CGFloat = 8
    let intraGroupSpacing: CGFloat = 0
    let separatorWidth: CGFloat = 1
    let aiPromptHeight: CGFloat = 40
    let aiPromptMinWidth: CGFloat = 240
    let aiPromptMaxWidth: CGFloat = 520
    let aiDashPattern: [CGFloat] = [6, 4, 1, 4]
    private let aiDashInterval: TimeInterval = 1.0 / 30.0
    private let aiDashIncrement: CGFloat = 1.2
    var aiDashPhase: CGFloat = 0
    private var aiDashTimer: Timer?
    let fontChoices: [(label: String, name: String)] = [
        ("System", NSFont.systemFont(ofSize: 16).fontName),
        ("Monospace", NSFont.monospacedSystemFont(ofSize: 16, weight: .regular).fontName),
        ("Helvetica Neue", "Helvetica Neue"),
        ("Avenir Next", "Avenir Next")
    ]

    var isToolMode: Bool {
        switch currentTool {
        case .pen, .line, .arrow, .rectangle, .ellipse:
            return true
        default:
            return false
        }
    }
    
    var isDrawingTool: Bool {
        switch currentTool {
        case .pen, .line, .arrow, .rectangle, .ellipse, .text:
            return true
        default:
            return false
        }
    }
    
    
    init(frame: NSRect, screenImage: CGImage, overlayId: UUID) {
        self.screenImage = screenImage
        self.overlayId = overlayId
        super.init(frame: frame)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.1).cgColor
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSelectionChange(_:)),
            name: .overlaySelectionDidChange,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let location: NSPoint
        if let window {
            if let event = NSApp.currentEvent,
               (event.type == .leftMouseDown || event.type == .rightMouseDown),
               event.window == window {
                location = convert(event.locationInWindow, from: nil)
            } else {
                location = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            }
        } else {
            location = superview != nil ? convert(point, from: superview) : point
        }
        if activeTextField != nil, !textControlPoints.isEmpty {
            let hitAreaExpansion: CGFloat = 8
            for controlPoint in textControlPoints {
                if controlPoint.insetBy(dx: -hitAreaExpansion, dy: -hitAreaExpansion).contains(location) {
                    return self
                }
            }
        }
        return super.hitTest(point)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopAIDashAnimation()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        drawFullScreenImage(in: context)
        drawDimOverlay(in: context)
        
        // Draw selection rectangle
        if let start = startPoint, let current = currentPoint, (mode == .creating || mode == .selecting), selectedRect == nil {
            let rect = normalizedRect(from: start, to: current)
            drawSelectionArea(rect, in: context)
            drawCenterGuides(for: rect, in: context)
            drawControlPoints(for: rect, in: context)
            drawSizeLabel(for: rect, in: context)
        } else if let rect = selectedRect {
            // Draw selected region
            drawSelectionArea(rect, in: context)
            drawCenterGuides(for: rect, in: context)
            
            // Draw all completed drawing elements
            for element in drawingElements {
                drawElement(element, in: context)
            }
            drawElementHighlights(in: context)
            
            // Draw current drawing
                if (mode == .creating || mode == .drawing), drawingStartPoint != nil {
                    drawCurrentDrawing(in: context)
                }
                if aiIsSendingPrompt, currentTool == .ai {
                    let borderRect = aiEditRect ?? rect
                    drawAIProcessingBorder(borderRect, in: context)
                } else {
                    if let aiRect = aiEditRect {
                        drawAIEditRect(aiRect, in: context)
                    } else if aiIsSelectingEditRect,
                              let start = aiEditStartPoint,
                              let current = aiEditCurrentPoint {
                        let aiRect = normalizedRect(from: start, to: current)
                        drawAIEditRect(aiRect, in: context)
                    }
                }
            
            // Draw control points
            drawControlPoints(for: rect, in: context)
            drawSizeLabel(for: rect, in: context)

            // Draw text area overlay when defining or editing
            if currentTool == .text, let start = textAreaDragStart, let current = textAreaDragCurrent {
                let textRect = normalizedRect(from: start, to: current)
                drawAIEditRect(textRect, in: context)
                drawControlPoints(for: textRect, in: context, size: 8)
            }
            if activeTextField != nil, let textRect = activeTextRect {
                drawAIEditRect(textRect, in: context)
                drawControlPoints(for: textRect, in: context, size: 8)
            }
        }
    }

    private func startAIDashAnimation() {
        guard aiDashTimer == nil else { return }
        aiDashPhase = 0
        let timer = Timer(timeInterval: aiDashInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let patternLength = self.aiDashPattern.reduce(0, +)
            self.aiDashPhase += self.aiDashIncrement
            if self.aiDashPhase > patternLength {
                self.aiDashPhase -= patternLength
            }
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        aiDashTimer = timer
    }

    private func stopAIDashAnimation() {
        aiDashTimer?.invalidate()
        aiDashTimer = nil
    }

    @objc func copyToClipboard() {
        guard let rect = selectedRect else { return }
        let finalImage = aiResultImage ?? renderFinalImage(for: rect)
        let nsImage = NSImage(cgImage: finalImage, size: NSSize(width: finalImage.width, height: finalImage.height))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        
        showNotification(message: "Copied to clipboard")
        NotificationCenter.default.post(name: .closeAllOverlays, object: nil)
    }

    @objc func saveImage() {
        guard let rect = selectedRect else { return }
        let finalImage = aiResultImage ?? renderFinalImage(for: rect)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // If you're a menu-bar/agent app, temporarily become a normal app
            let previousPolicy = NSApp.activationPolicy()
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png]
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            panel.nameFieldStringValue = "Screenshot-\(Int(Date().timeIntervalSince1970)).png"
            if let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first {
                panel.directoryURL = pictures
            }

            let restorePolicy: () -> Void = {
                // Put it back if you want to remain a menu-bar style app
                NSApp.setActivationPolicy(previousPolicy)
            }

            // Prefer a sheet if you have a window; otherwise use begin()
            if let window = NSApp.keyWindow ?? NSApp.windows.first {
                panel.beginSheetModal(for: window) { result in
                    defer { restorePolicy() }

                    if result == .OK, let targetURL = panel.url {
                        self.writePNG(finalImage, to: targetURL)
                        NotificationCenter.default.post(name: .closeAllOverlays, object: nil)
                    }
                }
            } else {
                panel.begin { result in
                    defer { restorePolicy() }

                    if result == .OK, let targetURL = panel.url {
                        self.writePNG(finalImage, to: targetURL)
                        NotificationCenter.default.post(name: .closeAllOverlays, object: nil)
                    }
                }
            }
        }
    }

    private func writePNG(_ image: CGImage, to url: URL) {
        if let destination = CGImageDestinationCreateWithURL(url as CFURL,
                                                            UTType.png.identifier as CFString,
                                                            1,
                                                            nil) {
            CGImageDestinationAddImage(destination, image, nil)
            if CGImageDestinationFinalize(destination) {
                showNotification(message: "Saved image")
            } else {
                showNotification(message: "Save failed")
            }
        } else {
            showNotification(message: "Save failed")
        }
    }

    
    @objc func closeOverlay() {
        NotificationCenter.default.post(name: .closeAllOverlays, object: nil)
    }
    
    @objc func openStrokeColorPicker() {
        activeColorTarget = .stroke
        toggleColorPicker()
    }

    @objc func openFillColorPicker() {
        activeColorTarget = .fill
        toggleColorPicker()
    }
    
    @objc func colorPicked(_ sender: NSButton) {
        guard let swatch = sender.layer?.backgroundColor else { return }
        let picked = NSColor(cgColor: swatch) ?? .clear
        switch activeColorTarget {
        case .stroke:
            currentStrokeColor = picked
            strokeColorButton?.swatchColor = picked
        case .fill:
            currentFillColor = picked == .clear ? nil : picked
            fillColorButton?.swatchColor = picked
        }
        hideColorPicker()
        needsDisplay = true
    }

    @objc func activateEyedropperFromPicker() {
        currentTool = .eyedropper
        updateToolButtonStates()
        hideColorPicker()
        eyedropperCursor.set()
        needsDisplay = true
    }
    
    private func showNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Screenshot"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    // Input handling moved to SelectionView+Input.swift
    
    func finishDrawing() {
        let element: DrawingElement
        
        switch currentTool {
        case .pen:
            element = DrawingElement(type: .pen(points: currentDrawingPoints), strokeColor: currentStrokeColor, fillColor: nil, lineWidth: currentLineWidth, fontSize: currentFontSize, fontName: currentFontName)
        case .line:
            if let start = drawingStartPoint, let end = currentDrawingPoints.last {
                element = DrawingElement(type: .line(start: start, end: end), strokeColor: currentStrokeColor, fillColor: nil, lineWidth: currentLineWidth, fontSize: currentFontSize, fontName: currentFontName)
            } else { return }
        case .arrow:
            if let start = drawingStartPoint, let end = currentDrawingPoints.last {
                element = DrawingElement(type: .arrow(start: start, end: end), strokeColor: currentStrokeColor, fillColor: nil, lineWidth: currentLineWidth, fontSize: currentFontSize, fontName: currentFontName)
            } else { return }
        case .rectangle:
            if let start = drawingStartPoint, let end = currentDrawingPoints.last {
                let rect = normalizedRect(from: start, to: end)
                element = DrawingElement(type: .rectangle(rect: rect), strokeColor: currentStrokeColor, fillColor: currentFillColor, lineWidth: currentLineWidth, fontSize: currentFontSize, fontName: currentFontName)
            } else { return }
        case .ellipse:
            if let start = drawingStartPoint, let end = currentDrawingPoints.last {
                let rect = normalizedRect(from: start, to: end)
                element = DrawingElement(type: .ellipse(rect: rect), strokeColor: currentStrokeColor, fillColor: currentFillColor, lineWidth: currentLineWidth, fontSize: currentFontSize, fontName: currentFontName)
            } else { return }
        case .text:
            return
        case .eraser:
            return
        case .eyedropper:
            return
        case .move:
            return
        case .select:
            return
        case .ai:
            return
        case .none:
            return
        }
        
        drawingElements.append(element)
    }
    
    func handleResize(corner: Int, to point: NSPoint) {
        guard var rect = selectedRect else { return }
        let minSize: CGFloat = 50
        
        switch corner {
        case 0: // Bottom-left
            rect.size.width = rect.maxX - point.x
            rect.size.height = rect.maxY - point.y
            rect.origin.x = point.x
            rect.origin.y = point.y
        case 1: // Bottom-right
            rect.size.width = point.x - rect.minX
            rect.size.height = rect.maxY - point.y
            rect.origin.y = point.y
        case 2: // Top-left
            rect.size.width = rect.maxX - point.x
            rect.size.height = point.y - rect.minY
            rect.origin.x = point.x
        case 3: // Top-right
            rect.size.width = point.x - rect.minX
            rect.size.height = point.y - rect.minY
        case 4: // Bottom-mid
            rect.size.height = rect.maxY - point.y
            rect.origin.y = point.y
        case 5: // Top-mid
            rect.size.height = point.y - rect.minY
        case 6: // Left-mid
            rect.size.width = rect.maxX - point.x
            rect.origin.x = point.x
        case 7: // Right-mid
            rect.size.width = point.x - rect.minX
        default:
            break
        }
        
        rect = rect.intersection(bounds)

        // Ensure minimum size
        if rect.width > minSize && rect.height > minSize {
            selectedRect = rect
            updateControlPoints()
        }
    }
    
    func updateControlPoints() {
        guard let rect = selectedRect else { return }
        controlPoints = controlPointRects(for: rect)
        window?.invalidateCursorRects(for: self)
    }

    func updateTextControlPoints() {
        guard let rect = activeTextRect else { return }
        textControlPoints = controlPointRects(for: rect, size: 8)
        window?.invalidateCursorRects(for: self)
    }

    func handleTextAreaResize(corner: Int, to point: NSPoint, rect: inout NSRect) {
        let clipRect = selectedRect ?? bounds
        let clampedPoint = NSPoint(
            x: min(max(clipRect.minX, point.x), clipRect.maxX),
            y: min(max(clipRect.minY, point.y), clipRect.maxY)
        )
        switch corner {
        case 0: // Bottom-left
            rect.size.width = rect.maxX - clampedPoint.x
            rect.size.height = rect.maxY - clampedPoint.y
            rect.origin.x = clampedPoint.x
            rect.origin.y = clampedPoint.y
        case 1: // Bottom-right
            rect.size.width = clampedPoint.x - rect.minX
            rect.size.height = rect.maxY - clampedPoint.y
            rect.origin.y = clampedPoint.y
        case 2: // Top-left
            rect.size.width = rect.maxX - clampedPoint.x
            rect.size.height = clampedPoint.y - rect.minY
            rect.origin.x = clampedPoint.x
        case 3: // Top-right
            rect.size.width = clampedPoint.x - rect.minX
            rect.size.height = clampedPoint.y - rect.minY
        case 4: // Bottom-mid
            rect.size.height = rect.maxY - clampedPoint.y
            rect.origin.y = clampedPoint.y
        case 5: // Top-mid
            rect.size.height = clampedPoint.y - rect.minY
        case 6: // Left-mid
            rect.size.width = rect.maxX - clampedPoint.x
            rect.origin.x = clampedPoint.x
        case 7: // Right-mid
            rect.size.width = clampedPoint.x - rect.minX
        default:
            break
        }
        rect = rect.intersection(clipRect)
        if rect.width < textAreaMinWidth { rect.size.width = textAreaMinWidth }
        if rect.height < textAreaMinHeight { rect.size.height = textAreaMinHeight }
        rect = rect.intersection(clipRect)
    }

    func updateToolButtonStates() {
        let hasApiKey = !SettingsStore.apiKeyValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if currentTool == .ai, !hasApiKey {
            currentTool = .move
        }
        toolButtons.forEach { button in
            button.state = .off
            button.isActiveAppearance = false
        }
        if let index = toolButtonTypes.firstIndex(of: currentTool),
           index < toolButtons.count {
            let button = toolButtons[index]
            button.state = .on
            button.isActiveAppearance = true
        }
        if let aiIndex = toolButtonTypes.firstIndex(of: .ai),
           aiIndex < toolButtons.count {
            let aiButton = toolButtons[aiIndex]
            aiButton.isEnabled = hasApiKey
            aiButton.alphaValue = hasApiKey ? 1.0 : 0.4
        }
        updateFontButtonState()
        updateAIPromptVisibility()
        if currentTool == .ai, hasApiKey {
            aiPromptField?.becomeFirstResponder()
        }
    }

    func updateFontButtonState() {
        let enabled = currentTool == .text
        fontSettingsButton?.isEnabled = enabled
        fontSettingsButton?.alphaValue = enabled ? 1.0 : 0.4
        if !enabled {
            hideFontPicker()
        }
    }

    func updateAIPromptVisibility() {
        guard currentTool == .ai, selectedRect != nil else {
            hideAIPrompt()
            return
        }
        showAIPrompt()
        aiIsSelectingEditRect = false
        aiEditRect = nil
        updateAIPromptPosition()
    }

    
    override var acceptsFirstResponder: Bool {
        return true
    }

    func clearToolbar() {
        toolButtons.forEach { $0.removeFromSuperview() }
        actionButtons.forEach { $0.removeFromSuperview() }
        separatorViews.forEach { $0.removeFromSuperview() }
        groupBorderViews.forEach { $0.removeFromSuperview() }
        strokeColorButton?.removeFromSuperview()
        fillColorButton?.removeFromSuperview()
        lineWidthButton?.removeFromSuperview()
        fontSettingsButton?.removeFromSuperview()
        toolButtons.removeAll()
        toolButtonTypes.removeAll()
        actionButtons.removeAll()
        separatorViews.removeAll()
        groupBorderViews.removeAll()
        strokeColorButton = nil
        fillColorButton = nil
        lineWidthButton = nil
        fontSettingsButton = nil
        hideColorPicker()
        hideLineWidthPicker()
        hideFontPicker()
        hideAIPrompt()
        toolbarView?.removeFromSuperview()
        toolbarView = nil
    }

    /// Returns average luminance (0–1) of the captured image in the view rect. Lower = darker.
    func averageLuminanceInViewRect(_ rect: NSRect) -> CGFloat? {
        let imageRect = imageRectForViewRect(rect)
        guard imageRect.width > 0, imageRect.height > 0,
              let dataProvider = screenImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }

        let bytesPerPixel = screenImage.bitsPerPixel / 8
        let bytesPerRow = screenImage.bytesPerRow
        let dataLength = CFDataGetLength(data)

        let minX = Int(imageRect.minX)
        let minY = Int(imageRect.minY)
        let maxX = min(Int(imageRect.maxX), screenImage.width)
        let maxY = min(Int(imageRect.maxY), screenImage.height)
        let step = max(1, min(maxX - minX, maxY - minY) / 16)
        var sum: CGFloat = 0
        var count = 0

        for y in stride(from: minY, to: maxY, by: step) {
            for x in stride(from: minX, to: maxX, by: step) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                guard offset + 3 < dataLength else { continue }
                let r = CGFloat(bytes[offset + 2]) / 255
                let g = CGFloat(bytes[offset + 1]) / 255
                let b = CGFloat(bytes[offset]) / 255
                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                sum += luminance
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return sum / CGFloat(count)
    }

    func colorAtViewPoint(_ point: NSPoint) -> NSColor? {
        guard let dataProvider = screenImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }

        let scaleX = CGFloat(screenImage.width) / bounds.width
        let scaleY = CGFloat(screenImage.height) / bounds.height
        let imageX = Int((point.x * scaleX).rounded(.down))
        let imageY = Int(((bounds.height - point.y) * scaleY).rounded(.down))

        let clampedX = max(0, min(screenImage.width - 1, imageX))
        let clampedY = max(0, min(screenImage.height - 1, imageY))
        let bytesPerPixel = screenImage.bitsPerPixel / 8
        let bytesPerRow = screenImage.bytesPerRow
        let offset = clampedY * bytesPerRow + clampedX * bytesPerPixel
        guard offset + 3 < CFDataGetLength(data) else { return nil }

        let b = bytes[offset]
        let g = bytes[offset + 1]
        let r = bytes[offset + 2]
        let a = bytes[offset + 3]
        return NSColor(
            calibratedRed: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }

    func eraseElement(at point: NSPoint) {
        let tolerance: CGFloat = 6
        for (index, element) in drawingElements.enumerated().reversed() {
            if elementHitTest(element, point: point, tolerance: tolerance) {
                drawingElements.remove(at: index)
                needsDisplay = true
                return
            }
        }
    }

    func elementHitTest(_ element: DrawingElement, point: NSPoint, tolerance: CGFloat) -> Bool {
        switch element.type {
        case .pen(let points):
            return polylineHitTest(points: points, point: point, tolerance: tolerance)
        case .line(let start, let end),
             .arrow(let start, let end):
            return distanceToSegment(point, start, end) <= tolerance
        case .rectangle(let rect):
            if element.fillColor != nil, rect.contains(point) {
                return true
            }
            return rectEdgeHitTest(rect, point: point, tolerance: tolerance)
        case .ellipse(let rect):
            if element.fillColor != nil, ellipseContainsPoint(rect, point: point) {
                return true
            }
            return ellipseEdgeHitTest(rect, point: point, tolerance: tolerance)
        case .text(_, let textRect):
            return textRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    func undoLastDrawing() {
        guard !drawingElements.isEmpty else { return }
        drawingElements.removeLast()
        needsDisplay = true
    }

    func translateDrawingElements(by delta: NSPoint) {
        guard !drawingElements.isEmpty else { return }
        drawingElements = drawingElements.map { element in
            translateElement(element, by: delta)
        }
    }

    func translateDrawingElement(at index: Int, by delta: NSPoint) {
        guard index >= 0, index < drawingElements.count else { return }
        drawingElements[index] = translateElement(drawingElements[index], by: delta)
    }

    private func translateElement(_ element: DrawingElement, by delta: NSPoint) -> DrawingElement {
        switch element.type {
        case .pen(let points):
            let translated = points.map { NSPoint(x: $0.x + delta.x, y: $0.y + delta.y) }
            return DrawingElement(type: .pen(points: translated), strokeColor: element.strokeColor, fillColor: element.fillColor, lineWidth: element.lineWidth, fontSize: element.fontSize, fontName: element.fontName)
        case .line(let start, let end):
            let newStart = NSPoint(x: start.x + delta.x, y: start.y + delta.y)
            let newEnd = NSPoint(x: end.x + delta.x, y: end.y + delta.y)
            return DrawingElement(type: .line(start: newStart, end: newEnd), strokeColor: element.strokeColor, fillColor: element.fillColor, lineWidth: element.lineWidth, fontSize: element.fontSize, fontName: element.fontName)
        case .arrow(let start, let end):
            let newStart = NSPoint(x: start.x + delta.x, y: start.y + delta.y)
            let newEnd = NSPoint(x: end.x + delta.x, y: end.y + delta.y)
            return DrawingElement(type: .arrow(start: newStart, end: newEnd), strokeColor: element.strokeColor, fillColor: element.fillColor, lineWidth: element.lineWidth, fontSize: element.fontSize, fontName: element.fontName)
        case .rectangle(let rect):
            let newRect = NSRect(
                x: rect.origin.x + delta.x,
                y: rect.origin.y + delta.y,
                width: rect.width,
                height: rect.height
            )
            return DrawingElement(type: .rectangle(rect: newRect), strokeColor: element.strokeColor, fillColor: element.fillColor, lineWidth: element.lineWidth, fontSize: element.fontSize, fontName: element.fontName)
        case .ellipse(let rect):
            let newRect = NSRect(
                x: rect.origin.x + delta.x,
                y: rect.origin.y + delta.y,
                width: rect.width,
                height: rect.height
            )
            return DrawingElement(type: .ellipse(rect: newRect), strokeColor: element.strokeColor, fillColor: element.fillColor, lineWidth: element.lineWidth, fontSize: element.fontSize, fontName: element.fontName)
        case .text(let text, let rect):
            let newRect = NSRect(
                x: rect.origin.x + delta.x,
                y: rect.origin.y + delta.y,
                width: rect.width,
                height: rect.height
            )
            return DrawingElement(type: .text(text: text, rect: newRect), strokeColor: element.strokeColor, fillColor: element.fillColor, lineWidth: element.lineWidth, fontSize: element.fontSize, fontName: element.fontName)
        }
    }

    func currentTextFont() -> NSFont {
        if let font = NSFont(name: currentFontName, size: currentFontSize) {
            return font
        }
        return NSFont.systemFont(ofSize: currentFontSize, weight: .semibold)
    }

    func fontFromElement(_ element: DrawingElement, size: CGFloat? = nil) -> NSFont {
        let targetSize = size ?? element.fontSize
        if let font = NSFont(name: element.fontName, size: targetSize) {
            return font
        }
        return NSFont.systemFont(ofSize: targetSize, weight: .semibold)
    }

    func startTextEntry(at point: NSPoint) {
        let sel = selectedRect ?? bounds
        var rect = NSRect(x: point.x, y: point.y - textAreaDefaultHeight, width: textAreaDefaultWidth, height: textAreaDefaultHeight)
        rect = rect.intersection(sel)
        if rect.width < textAreaMinWidth { rect.size.width = textAreaMinWidth }
        if rect.height < textAreaMinHeight { rect.size.height = textAreaMinHeight }
        rect = rect.intersection(sel)
        startTextEntry(in: rect)
    }

    func startTextEntry(in rect: NSRect) {
        activeTextField?.removeFromSuperview()
        activeTextField = nil

        let clipRect = rect.intersection(selectedRect ?? bounds)
        let field = NSTextField(frame: clipRect)
        field.delegate = self
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        let font = currentTextFont()
        let placeholderColor: NSColor
        if let luminance = averageLuminanceInViewRect(clipRect) {
            placeholderColor = luminance < 0.5 ? .white : .black
        } else {
            placeholderColor = .gray
        }
        (field.cell as? NSTextFieldCell)?.placeholderAttributedString = NSAttributedString(
            string: "Type text here",
            attributes: [.foregroundColor: placeholderColor, .font: font]
        )
        field.textColor = currentStrokeColor
        field.font = font
        field.cell?.lineBreakMode = .byWordWrapping
        field.cell?.truncatesLastVisibleLine = false
        field.cell?.usesSingleLineMode = false
        field.wantsLayer = true
        field.layer?.masksToBounds = true
        addSubview(field)
        window?.makeFirstResponder(field)
        activeTextField = field
        activeTextRect = clipRect
        mode = .editing
        updateTextControlPoints()
    }

    func startTextEdit(for element: DrawingElement, at index: Int) {
        guard case .text(let text, let rect) = element.type else { return }
        editingTextElementIndex = index
        editingTextOriginalElement = element
        mode = .editing
        if index >= 0, index < drawingElements.count {
            drawingElements.remove(at: index)
        }
        selectedElementIndex = nil
        hoverEraserIndex = nil
        currentTool = .text
        currentStrokeColor = element.strokeColor
        currentFontSize = element.fontSize
        currentFontName = element.fontName
        currentLineWidth = element.lineWidth
        strokeColorButton?.swatchColor = currentStrokeColor
        updateToolButtonStates()
        startTextEntry(in: rect)
        activeTextField?.stringValue = text
        activeTextField?.textColor = currentStrokeColor
        activeTextField?.font = fontFromElement(element)
        updateTextControlPoints()
        needsDisplay = true
    }
    
    func controlTextDidEndEditing(_ notification: Notification) {
        // If resigning due to clicking a text control point, we must not finish yet -
        // the field resigns before mouseDown, which would clear state. Defer and skip
        // finish when we're about to resize via control points.
        if activeTextField != nil, let rect = activeTextRect, let window {
            let loc = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            let expanded = controlPointRects(for: rect, size: 8).map { $0.insetBy(dx: -8, dy: -8) }
            if expanded.contains(where: { $0.contains(loc) }) {
                isDeferringTextFinishForResize = true
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    defer { self.isDeferringTextFinishForResize = false }
                    if self.mode == .resizing, self.resizingTextAreaCorner != nil {
                        return
                    }
                    self.finishActiveTextEntry(commit: true)
                }
                return
            }
        }
        finishActiveTextEntry(commit: true)
    }

    func finishActiveTextEntry(commit: Bool) {
        guard let field = activeTextField, !isFinishingTextEntry else { return }
        isFinishingTextEntry = true
        defer { isFinishingTextEntry = false }
        if commit {
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, let rect = activeTextRect {
                let element = DrawingElement(
                    type: .text(text: text, rect: rect),
                    strokeColor: currentStrokeColor,
                    fillColor: nil,
                    lineWidth: currentLineWidth,
                    fontSize: currentFontSize,
                    fontName: currentFontName
                )
                if let index = editingTextElementIndex {
                    let targetIndex = min(index, drawingElements.count)
                    drawingElements.insert(element, at: targetIndex)
                } else {
                    drawingElements.append(element)
                }
            }
        } else if let original = editingTextOriginalElement, let index = editingTextElementIndex {
            let targetIndex = min(index, drawingElements.count)
            drawingElements.insert(original, at: targetIndex)
        }
        field.removeFromSuperview()
        activeTextField = nil
        activeTextRect = nil
        textControlPoints.removeAll()
        editingTextElementIndex = nil
        editingTextOriginalElement = nil
        mode = .editing
        needsDisplay = true
    }

    func notifySelectionChanged() {
        NotificationCenter.default.post(
            name: .overlaySelectionDidChange,
            object: nil,
            userInfo: ["overlayId": overlayId]
        )
    }

    @objc private func handleSelectionChange(_ notification: Notification) {
        guard let senderId = notification.userInfo?["overlayId"] as? UUID else { return }
        guard senderId != overlayId else { return }
        clearSelection()
    }

    private func clearSelection() {
        mode = .creating
        startPoint = nil
        currentPoint = nil
        selectedRect = nil
        controlPoints.removeAll()
        drawingElements.removeAll()
        currentTool = .move
        activeTextField?.removeFromSuperview()
        activeTextField = nil
        activeTextRect = nil
        textControlPoints.removeAll()
        editingTextElementIndex = nil
        editingTextOriginalElement = nil
        clearToolbar()
        needsDisplay = true
    }
}
