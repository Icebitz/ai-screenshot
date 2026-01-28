import Cocoa
import UniformTypeIdentifiers
import UserNotifications

extension Notification.Name {
    static let overlaySelectionDidChange = Notification.Name("ScreenshotApp.OverlaySelectionDidChange")
}

class OverlayWindow: NSWindow {
    let screenImage: CGImage
    let displayBounds: CGRect
    let overlayId = UUID()
    var selectionView: SelectionView?
    var onClose: (() -> Void)?
    
    init(screenImage: CGImage, displayBounds: CGRect) {
        self.screenImage = screenImage
        self.displayBounds = displayBounds
        
        super.init(
            contentRect: displayBounds,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        
        setupSelectionView()
    }
    
    private func setupSelectionView() {
        selectionView = SelectionView(frame: self.frame, screenImage: screenImage, overlayId: overlayId)
        selectionView?.overlayWindow = self
        self.contentView = selectionView
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func becomeKey() {
        super.becomeKey()
        self.makeFirstResponder(selectionView)
    }

    override func close() {
        super.close()
        onClose?()
    }
}

enum SelectionMode {
    case selecting      // Initial drag to create selection
    case selected       // Region selected, showing tools
    case dragging       // Moving the selection
    case resizing       // Resizing via control points
    case drawing        // Drawing on the image
    case elementDragging // Moving a drawn element
}

enum DrawingTool {
    case none
    case pen
    case line
    case arrow
    case rectangle
    case circle
    case text
    case eraser
    case eyedropper
}

enum ColorTarget {
    case stroke
    case fill
}

struct DrawingElement {
    enum ElementType {
        case pen(points: [NSPoint])
        case line(start: NSPoint, end: NSPoint)
        case arrow(start: NSPoint, end: NSPoint)
        case rectangle(rect: NSRect)
        case circle(rect: NSRect)
        case text(text: String, point: NSPoint)
    }
    
    let type: ElementType
    let strokeColor: NSColor
    let fillColor: NSColor?
    let lineWidth: CGFloat
    let fontSize: CGFloat
    let fontName: String
}

final class ToolbarButton: NSButton {
    var baseColor = NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.26, alpha: 1.0)
    var accentColor: NSColor?
    var isActiveAppearance = false {
        didSet { needsDisplay = true }
    }

    private let gradientLayer = CAGradientLayer()

    override var isHighlighted: Bool {
        didSet { needsDisplay = true }
    }

    override func updateLayer() {
        wantsLayer = true
        guard let layer = layer else { return }

        let base = isActiveAppearance ? (accentColor ?? baseColor) : baseColor
        let top = base.highlight(withLevel: isHighlighted ? 0.05 : 0.20) ?? base
        let bottom = base.shadow(withLevel: isHighlighted ? 0.35 : 0.25) ?? base

        if gradientLayer.superlayer == nil {
            layer.addSublayer(gradientLayer)
        }

        gradientLayer.frame = bounds
        gradientLayer.colors = [top.cgColor, bottom.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.cornerRadius = 6

        layer.cornerRadius = 6
        layer.borderWidth = 1
        layer.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.10).cgColor
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: -1)
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }
}

final class ColorSwatchButton: NSButton {
    var swatchColor: NSColor = .red {
        didSet { needsDisplay = true }
    }

    override var isHighlighted: Bool {
        didSet { alphaValue = isHighlighted ? 0.8 : 1.0 }
    }

    override func updateLayer() {
        wantsLayer = true
        guard let layer = layer else { return }
        layer.cornerRadius = 6
        layer.backgroundColor = swatchColor.cgColor
        layer.borderWidth = 1
        layer.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.18).cgColor
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: -1)
    }
}

class SelectionView: NSView, NSTextFieldDelegate {
    let screenImage: CGImage
    let overlayId: UUID
    weak var overlayWindow: OverlayWindow?
    
    // Selection state
    var mode: SelectionMode = .selecting
    var startPoint: NSPoint?
    var currentPoint: NSPoint?
    var selectedRect: NSRect?
    
    // Resizing/dragging
    var controlPoints: [NSRect] = []
    var dragOffset: NSPoint = .zero
    var resizingCorner: Int? = nil
    var lastDragPoint: NSPoint?
    
    // Drawing
    var currentTool: DrawingTool = .none
    var currentStrokeColor: NSColor = .red
    var currentFillColor: NSColor? = nil
    var currentLineWidth: CGFloat = 3.0
    var drawingElements: [DrawingElement] = []
    var currentDrawingPoints: [NSPoint] = []
    var drawingStartPoint: NSPoint?
    var currentFontSize: CGFloat = 16
    var currentFontName: String = NSFont.systemFont(ofSize: 16).fontName
    var activeTextField: NSTextField?
    var activeTextOrigin: NSPoint?
    var selectedElementIndex: Int?
    var hoverEraserIndex: Int?
    private var trackingArea: NSTrackingArea?
    
    // UI Elements
    var toolButtons: [NSButton] = []
    var toolButtonTypes: [DrawingTool] = []
    var actionButtons: [NSButton] = []
    var toolbarView: NSVisualEffectView?
    var separatorViews: [NSView] = []
    var strokeColorButton: ColorSwatchButton?
    var fillColorButton: ColorSwatchButton?
    var lineWidthButton: ToolbarButton?
    var fontSettingsButton: ToolbarButton?
    var colorPickerView: NSView?
    var lineWidthPickerView: NSView?
    var fontPickerView: NSView?
    var activeColorTarget: ColorTarget = .stroke

    private let toolButtonWidth: CGFloat = 28
    private let actionButtonWidth: CGFloat = 28
    private let toolbarPadding: CGFloat = 10
    private let buttonSpacing: CGFloat = 8
    private let separatorWidth: CGFloat = 1
    private let fontChoices: [(label: String, name: String)] = [
        ("System", NSFont.systemFont(ofSize: 16).fontName),
        ("Monospace", NSFont.monospacedSystemFont(ofSize: 16, weight: .regular).fontName),
        ("Helvetica Neue", "Helvetica Neue"),
        ("Avenir Next", "Avenir Next")
    ]
    
    
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        drawFullScreenImage(in: context)
        drawDimOverlay(in: context)
        
        // Draw selection rectangle
        if let start = startPoint, let current = currentPoint, mode == .selecting {
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
            if mode == .drawing {
                drawCurrentDrawing(in: context)
            }
            
            // Draw control points
            if currentTool == .none {
                drawControlPoints(for: rect, in: context)
            }
            drawSizeLabel(for: rect, in: context)
        }
    }
    
    private func drawSelectionArea(_ rect: NSRect, in context: CGContext) {
        context.setBlendMode(.normal)
        let imageRect = imageRectForViewRect(rect)
        
        // Draw the screen image in the selection area
        if let croppedImage = screenImage.cropping(to: imageRect) {
            context.draw(croppedImage, in: rect)
        }
        
        // Draw selection border
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)
    }

    private func drawFullScreenImage(in context: CGContext) {
        context.draw(screenImage, in: bounds)
    }

    private func drawDimOverlay(in context: CGContext) {
        context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        context.fill(bounds)
    }
    
    private func drawSizeLabel(for rect: NSRect, in context: CGContext) {
        let width = Int(rect.width)
        let height = Int(rect.height)
        let text = "\(width) × \(height)"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        
        let paddingX: CGFloat = 12
        let paddingY: CGFloat = 6
        let bubbleSize = NSSize(width: textSize.width + paddingX * 2, height: textSize.height + paddingY * 2)

        var bubbleOrigin = NSPoint(
            x: rect.midX - bubbleSize.width / 2,
            y: rect.maxY - bubbleSize.height / 2
        )
        
        if bubbleOrigin.y + bubbleSize.height > bounds.maxY - 4 {
            bubbleOrigin.y = bounds.maxY - bubbleSize.height - 4
        }
        if bubbleOrigin.y < 4 {
            bubbleOrigin.y = 4
        }

        if bubbleOrigin.x < 4 { bubbleOrigin.x = 4 }
        if bubbleOrigin.x + bubbleSize.width > bounds.maxX - 4 {
            bubbleOrigin.x = bounds.maxX - bubbleSize.width - 4
        }

        let bubbleRect = NSRect(origin: bubbleOrigin, size: bubbleSize)
        let bubblePath = NSBezierPath(roundedRect: bubbleRect, xRadius: 6, yRadius: 6)

        context.saveGState()
        context.setShadow(offset: .zero, blur: 6, color: NSColor.black.withAlphaComponent(0.35).cgColor)
        context.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 0.85).cgColor)
        context.addPath(bubblePath.cgPath)
        context.fillPath()
        context.restoreGState()

        let textRect = NSRect(
            x: bubbleRect.minX + paddingX,
            y: bubbleRect.minY + paddingY - 1,
            width: textSize.width,
            height: textSize.height
        )

        attributedString.draw(in: textRect)
    }
    
    private func drawElement(_ element: DrawingElement, in context: CGContext) {
        context.setStrokeColor(element.strokeColor.cgColor)
        context.setLineWidth(element.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        switch element.type {
        case .pen(let points):
            guard points.count > 1 else { return }
            context.beginPath()
            context.move(to: points[0])
            for point in points.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
            
        case .line(let start, let end):
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            
        case .arrow(let start, let end):
            drawArrow(from: start, to: end, in: context, color: element.strokeColor, lineWidth: element.lineWidth)
            
        case .rectangle(let rect):
            if let fillColor = element.fillColor {
                context.setFillColor(fillColor.cgColor)
                context.fill(rect)
            }
            context.stroke(rect)
            
        case .circle(let rect):
            if let fillColor = element.fillColor {
                context.setFillColor(fillColor.cgColor)
                context.fillEllipse(in: rect)
            }
            context.strokeEllipse(in: rect)
            
        case .text(let text, let point):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: fontFromElement(element),
                .foregroundColor: element.strokeColor
            ]
            NSString(string: text).draw(at: point, withAttributes: attributes)
        }
    }

    private func drawElementHighlights(in context: CGContext) {
        if let index = selectedElementIndex, index < drawingElements.count {
            drawElementGlow(drawingElements[index], in: context, color: NSColor.systemBlue.withAlphaComponent(0.6))
        }
        if let index = hoverEraserIndex, index < drawingElements.count {
            drawElementGlow(drawingElements[index], in: context, color: NSColor.systemRed.withAlphaComponent(0.6))
        }
    }

    private func drawElementGlow(_ element: DrawingElement, in context: CGContext, color: NSColor) {
        context.saveGState()
        context.setShadow(offset: .zero, blur: 6, color: color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(max(2, element.lineWidth))
        switch element.type {
        case .pen(let points):
            guard points.count > 1 else { break }
            context.beginPath()
            context.move(to: points[0])
            for point in points.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        case .line(let start, let end):
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        case .arrow(let start, let end):
            drawArrow(from: start, to: end, in: context, color: color, lineWidth: max(2, element.lineWidth))
        case .rectangle(let rect):
            context.stroke(rect.insetBy(dx: -2, dy: -2))
        case .circle(let rect):
            context.strokeEllipse(in: rect.insetBy(dx: -2, dy: -2))
        case .text(let text, let point):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: fontFromElement(element),
                .foregroundColor: color
            ]
            NSString(string: text).draw(at: point, withAttributes: attributes)
        }
        context.restoreGState()
    }
    
    private func drawCurrentDrawing(in context: CGContext) {
        context.setStrokeColor(currentStrokeColor.cgColor)
        context.setLineWidth(currentLineWidth)
        context.setLineCap(.round)
        
        switch currentTool {
        case .pen:
            if currentDrawingPoints.count > 1 {
                context.beginPath()
                context.move(to: currentDrawingPoints[0])
                for point in currentDrawingPoints.dropFirst() {
                    context.addLine(to: point)
                }
                context.strokePath()
            }
        case .line:
            if let start = drawingStartPoint, let current = currentDrawingPoints.last {
                context.beginPath()
                context.move(to: start)
                context.addLine(to: current)
                context.strokePath()
            }
        case .arrow:
            if let start = drawingStartPoint, let current = currentDrawingPoints.last {
                drawArrow(from: start, to: current, in: context, color: currentStrokeColor, lineWidth: currentLineWidth)
            }
        case .rectangle:
            if let start = drawingStartPoint, let current = currentDrawingPoints.last {
                let rect = normalizedRect(from: start, to: current)
                if let fillColor = currentFillColor {
                    context.setFillColor(fillColor.cgColor)
                    context.fill(rect)
                }
                context.stroke(rect)
            }
        case .circle:
            if let start = drawingStartPoint, let current = currentDrawingPoints.last {
                let rect = normalizedRect(from: start, to: current)
                if let fillColor = currentFillColor {
                    context.setFillColor(fillColor.cgColor)
                    context.fillEllipse(in: rect)
                }
                context.strokeEllipse(in: rect)
            }
        case .text:
            break
        case .eraser:
            break
        case .eyedropper:
            break
        case .none:
            break
        }
    }
    
    private func drawArrow(from start: CGPoint, to end: CGPoint, in context: CGContext, color: NSColor, lineWidth: CGFloat) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        
        // Draw line
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        
        // Draw arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        context.beginPath()
        context.move(to: point1)
        context.addLine(to: end)
        context.addLine(to: point2)
        context.strokePath()
    }

    private func drawControlPoints(for rect: NSRect, in context: CGContext) {
        let points = controlPointRects(for: rect)
        guard !points.isEmpty else { return }

        let fillColor = NSColor(calibratedRed: 0.45, green: 0.86, blue: 1.0, alpha: 1.0)
        let strokeColor = NSColor(calibratedRed: 0.18, green: 0.35, blue: 0.55, alpha: 1.0)
        let glowColor = NSColor(calibratedRed: 0.45, green: 0.86, blue: 1.0, alpha: 0.7)

        for pointRect in points {
            let handleRect = pointRect.insetBy(dx: -1, dy: -1)
            let path = NSBezierPath(roundedRect: handleRect, xRadius: 2, yRadius: 2)

            context.saveGState()
            context.setShadow(offset: .zero, blur: 6, color: glowColor.cgColor)
            context.setFillColor(fillColor.cgColor)
            context.addPath(path.cgPath)
            context.fillPath()
            context.restoreGState()

            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(1)
            context.addPath(path.cgPath)
            context.strokePath()
        }
    }

    private func drawCenterGuides(for rect: NSRect, in context: CGContext) {
        let guideColor = NSColor(calibratedWhite: 1.0, alpha: 0.55)
        context.saveGState()
        context.setStrokeColor(guideColor.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [4, 4])

        let midX = rect.midX
        let midY = rect.midY

        context.beginPath()
        context.move(to: CGPoint(x: rect.minX, y: midY))
        context.addLine(to: CGPoint(x: rect.maxX, y: midY))
        context.move(to: CGPoint(x: midX, y: rect.minY))
        context.addLine(to: CGPoint(x: midX, y: rect.maxY))
        context.strokePath()
        context.restoreGState()
    }

    private func setupToolbar(for rect: NSRect) {
        clearToolbar()

        // Place toolbar centered on the bottom edge of the selection
        let toolbarHeight: CGFloat = 36
        var toolbarY = rect.minY - toolbarHeight / 2
        toolbarY = min(max(4, toolbarY), bounds.maxY - toolbarHeight - 4)

        let toolbarFrame = toolbarFrameForSelection(rect, y: toolbarY)
        let toolbar = NSVisualEffectView(frame: toolbarFrame)
        toolbar.material = .hudWindow
        toolbar.blendingMode = .withinWindow
        toolbar.state = .active
        toolbar.appearance = NSAppearance(named: .vibrantDark)
        toolbar.wantsLayer = true
        toolbar.layer?.cornerRadius = 8
        toolbar.layer?.borderWidth = 1
        toolbar.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.10).cgColor
        toolbar.layer?.shadowColor = NSColor.black.cgColor
        toolbar.layer?.shadowOpacity = 0.35
        toolbar.layer?.shadowRadius = 8
        toolbar.layer?.shadowOffset = CGSize(width: 0, height: -2)
        toolbarView = toolbar
        addSubview(toolbar)
        
        // Action buttons (left)
        let contentWidth = toolbarContentWidth()
        var xOffset = toolbarGroupStartX(toolbarWidth: toolbarFrame.width, contentWidth: contentWidth)
        let copyButton = createActionButton(icon: "doc.on.doc", x: xOffset, y: 4, action: #selector(copyToClipboard))
        xOffset += actionButtonWidth + buttonSpacing
        let saveButton = createActionButton(icon: "square.and.arrow.down", x: xOffset, y: 4, action: #selector(saveImage))
        xOffset += actionButtonWidth + buttonSpacing
        let closeButton = createActionButton(icon: "xmark.circle.fill", x: xOffset, y: 4, action: #selector(closeOverlay))
        xOffset += actionButtonWidth + buttonSpacing
        
        actionButtons = [copyButton, saveButton, closeButton]
        actionButtons.forEach { toolbar.addSubview($0) }
        
        let actionToolSeparator = createSeparator(height: 20)
        actionToolSeparator.frame.origin = NSPoint(x: xOffset, y: 8)
        separatorViews.append(actionToolSeparator)
        toolbar.addSubview(actionToolSeparator)
        xOffset += separatorWidth + buttonSpacing

        // Tool buttons (right)
        let tools: [(String, DrawingTool)] = [
            ("cursorarrow", .none),
            ("pencil", .pen),
            ("line.diagonal", .line),
            ("arrow.up.right", .arrow),
            ("rectangle", .rectangle),
            ("circle", .circle),
            ("textformat", .text),
            ("eraser", .eraser),
            ("eyedropper", .eyedropper)
        ]
        
        toolButtonTypes = tools.map { $0.1 }
        for (icon, tool) in tools {
            let button = createToolButton(icon: icon, tool: tool, x: xOffset, y: 4)
            toolButtons.append(button)
            toolbar.addSubview(button)
            xOffset += toolButtonWidth + buttonSpacing
        }
        
        let toolColorSeparator = createSeparator(height: 20)
        toolColorSeparator.frame.origin = NSPoint(x: xOffset, y: 8)
        separatorViews.append(toolColorSeparator)
        toolbar.addSubview(toolColorSeparator)
        xOffset += separatorWidth + buttonSpacing

        let strokeButton = ColorSwatchButton(frame: NSRect(x: xOffset, y: 4, width: toolButtonWidth, height: 28))
        strokeButton.title = ""
        strokeButton.image = nil
        strokeButton.isBordered = false
        strokeButton.swatchColor = currentStrokeColor
        strokeButton.target = self
        strokeButton.action = #selector(openStrokeColorPicker)
        strokeColorButton = strokeButton
        toolbar.addSubview(strokeButton)
        xOffset += toolButtonWidth + buttonSpacing

        let fillButton = ColorSwatchButton(frame: NSRect(x: xOffset, y: 4, width: toolButtonWidth, height: 28))
        fillButton.title = ""
        fillButton.image = nil
        fillButton.isBordered = false
        fillButton.swatchColor = currentFillColor ?? .clear
        fillButton.target = self
        fillButton.action = #selector(openFillColorPicker)
        fillColorButton = fillButton
        toolbar.addSubview(fillButton)
        xOffset += toolButtonWidth + buttonSpacing

        let widthButton = createIconButton(icon: "line.3.horizontal.decrease.circle", x: xOffset, y: 4)
        widthButton.target = self
        widthButton.action = #selector(toggleLineWidthPicker)
        widthButton.isActiveAppearance = false
        lineWidthButton = widthButton
        toolbar.addSubview(widthButton)
        xOffset += toolButtonWidth + buttonSpacing

        let fontButton = createIconButton(icon: "textformat.size", x: xOffset, y: 4)
        fontButton.target = self
        fontButton.action = #selector(toggleFontPicker)
        fontButton.isActiveAppearance = false
        fontSettingsButton = fontButton
        toolbar.addSubview(fontButton)
    }

    private func createToolButton(icon: String, tool: DrawingTool, x: CGFloat, y: CGFloat) -> NSButton {
        let button = ToolbarButton(frame: NSRect(x: x, y: y, width: toolButtonWidth, height: 28))
        if let customImage = NSImage(named: icon) {
            button.image = customImage
            button.image?.isTemplate = true
        } else {
            button.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        }
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(toolSelected(_:))
        button.tag = tool.hashValue
        button.contentTintColor = NSColor.white
        
        button.accentColor = NSColor(calibratedRed: 0.20, green: 0.64, blue: 1.0, alpha: 1.0)
        button.isActiveAppearance = (tool == .none)
        
        return button
    }

    private func createIconButton(icon: String, x: CGFloat, y: CGFloat) -> ToolbarButton {
        let button = ToolbarButton(frame: NSRect(x: x, y: y, width: toolButtonWidth, height: 28))
        if let customImage = NSImage(named: icon) {
            button.image = customImage
            button.image?.isTemplate = true
        } else {
            button.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        }
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = NSColor.white
        button.accentColor = NSColor(calibratedRed: 0.20, green: 0.64, blue: 1.0, alpha: 1.0)
        return button
    }
    
    private func createActionButton(icon: String, x: CGFloat, y: CGFloat, action: Selector) -> NSButton {
        let button = ToolbarButton(frame: NSRect(x: x, y: y, width: actionButtonWidth, height: 28))
        if let customImage = NSImage(named: icon) {
            button.image = customImage
            button.image?.isTemplate = true
        } else {
            if let symbolImage = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
                button.image = symbolImage
            }
        }
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        button.contentTintColor = NSColor.white
        
        return button
    }
    
    @objc private func toolSelected(_ sender: NSButton) {
        if let index = toolButtons.firstIndex(of: sender), index < toolButtonTypes.count {
            let nextTool = toolButtonTypes[index]
            if currentTool == .text, nextTool != .text {
                finishActiveTextEntry(commit: true)
            }
            if currentTool == .eraser, nextTool != .eraser {
                hoverEraserIndex = nil
            }
            currentTool = nextTool
            
            // Update button states
            updateToolButtonStates()
            
            needsDisplay = true
        }
    }
    
    @objc private func copyToClipboard() {
        guard let rect = selectedRect else { return }
        let finalImage = renderFinalImage(for: rect)
        let nsImage = NSImage(cgImage: finalImage, size: NSSize(width: finalImage.width, height: finalImage.height))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        
        showNotification(message: "Copied to clipboard")
        NotificationCenter.default.post(name: .closeAllOverlays, object: nil)
    }

    @objc private func saveImage() {
        guard let rect = selectedRect else { return }
        let finalImage = renderFinalImage(for: rect)
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "Screenshot \(Date().timeIntervalSince1970).png"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, finalImage, nil)
                    CGImageDestinationFinalize(destination)
                    self.showNotification(message: "Image saved")
                }
            }
        }
        NotificationCenter.default.post(name: .closeAllOverlays, object: nil)
    }
    
    @objc private func closeOverlay() {
        NotificationCenter.default.post(name: .closeAllOverlays, object: nil)
    }
    
    @objc private func openStrokeColorPicker() {
        activeColorTarget = .stroke
        toggleColorPicker()
    }

    @objc private func openFillColorPicker() {
        activeColorTarget = .fill
        toggleColorPicker()
    }
    
    @objc private func colorPicked(_ sender: NSButton) {
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

    private func renderFinalImage(for rect: NSRect) -> CGImage {
        let imageRect = imageRectForViewRect(rect)
        let width = Int(imageRect.width)
        let height = Int(imageRect.height)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return screenImage.cropping(to: rect) ?? screenImage
        }
        
        // Draw cropped screen image
        if let croppedImage = screenImage.cropping(to: imageRect) {
            context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        // Draw all drawing elements (offset by rect origin)
        let scaleX = CGFloat(width) / rect.width
        let scaleY = CGFloat(height) / rect.height
        for element in drawingElements {
            drawElementWithOffset(element, in: context, offset: rect.origin, scaleX: scaleX, scaleY: scaleY)
        }
        
        return context.makeImage() ?? (screenImage.cropping(to: imageRect) ?? screenImage)
    }

    private func drawElementWithOffset(_ element: DrawingElement, in context: CGContext, offset: NSPoint, scaleX: CGFloat, scaleY: CGFloat) {
        context.setStrokeColor(element.strokeColor.cgColor)
        context.setLineWidth(element.lineWidth * max(scaleX, scaleY))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        switch element.type {
        case .pen(let points):
            guard points.count > 1 else { return }
            context.beginPath()
            let firstPoint = points[0]
            context.move(to: CGPoint(
                x: (firstPoint.x - offset.x) * scaleX,
                y: (firstPoint.y - offset.y) * scaleY
            ))
            for point in points.dropFirst() {
                context.addLine(to: CGPoint(
                    x: (point.x - offset.x) * scaleX,
                    y: (point.y - offset.y) * scaleY
                ))
            }
            context.strokePath()
            
        case .line(let start, let end):
            context.beginPath()
            context.move(to: CGPoint(
                x: (start.x - offset.x) * scaleX,
                y: (start.y - offset.y) * scaleY
            ))
            context.addLine(to: CGPoint(
                x: (end.x - offset.x) * scaleX,
                y: (end.y - offset.y) * scaleY
            ))
            context.strokePath()
            
        case .arrow(let start, let end):
            let adjustedStart = CGPoint(
                x: (start.x - offset.x) * scaleX,
                y: (start.y - offset.y) * scaleY
            )
            let adjustedEnd = CGPoint(
                x: (end.x - offset.x) * scaleX,
                y: (end.y - offset.y) * scaleY
            )
            drawArrow(from: adjustedStart, to: adjustedEnd, in: context, color: element.strokeColor, lineWidth: element.lineWidth * max(scaleX, scaleY))
            
        case .rectangle(let rect):
            let adjustedRect = CGRect(
                x: (rect.origin.x - offset.x) * scaleX,
                y: (rect.origin.y - offset.y) * scaleY,
                width: rect.width * scaleX,
                height: rect.height * scaleY
            )
            if let fillColor = element.fillColor {
                context.setFillColor(fillColor.cgColor)
                context.fill(adjustedRect)
            }
            context.stroke(adjustedRect)
            
        case .circle(let rect):
            let adjustedRect = CGRect(
                x: (rect.origin.x - offset.x) * scaleX,
                y: (rect.origin.y - offset.y) * scaleY,
                width: rect.width * scaleX,
                height: rect.height * scaleY
            )
            if let fillColor = element.fillColor {
                context.setFillColor(fillColor.cgColor)
                context.fillEllipse(in: adjustedRect)
            }
            context.strokeEllipse(in: adjustedRect)
            
        case .text(let text, let point):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: fontFromElement(element, size: element.fontSize * scaleY),
                .foregroundColor: element.strokeColor
            ]
            let adjustedPoint = CGPoint(
                x: (point.x - offset.x) * scaleX,
                y: (point.y - offset.y) * scaleY
            )
            let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphicsContext
            NSString(string: text).draw(at: adjustedPoint, withAttributes: attributes)
            NSGraphicsContext.restoreGraphicsState()
        }
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

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        // Check if clicking on control points for resizing
        if currentTool == .none, let _ = selectedRect {
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
                    currentStrokeColor = picked
                    strokeColorButton?.swatchColor = picked
                }
                currentTool = .none
                updateToolButtonStates()
                needsDisplay = true
                return
            }
            if currentTool == .none {
                if let index = drawingElements.lastIndex(where: { elementHitTest($0, point: location, tolerance: 6) }) {
                    selectedElementIndex = index
                    mode = .elementDragging
                    lastDragPoint = location
                    NSCursor.closedHand.set()
                    needsDisplay = true
                    return
                }
                selectedElementIndex = nil
            }
            if currentTool != .none {
                // Start drawing
                mode = .drawing
                drawingStartPoint = location
                currentDrawingPoints = [location]
            } else {
                // Start dragging
                mode = .dragging
                dragOffset = NSPoint(x: location.x - rect.origin.x, y: location.y - rect.origin.y)
                NSCursor.closedHand.set()
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
        
        clearToolbar()
        notifySelectionChanged()
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        switch mode {
        case .selecting:
            currentPoint = clampedPoint(location)
            needsDisplay = true
            
        case .dragging:
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
                mode = .selected
                updateControlPoints()
                setupToolbar(for: clampedRect)
                notifySelectionChanged()
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
    
    private func finishDrawing() {
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
        case .circle:
            if let start = drawingStartPoint, let end = currentDrawingPoints.last {
                let rect = normalizedRect(from: start, to: end)
                element = DrawingElement(type: .circle(rect: rect), strokeColor: currentStrokeColor, fillColor: currentFillColor, lineWidth: currentLineWidth, fontSize: currentFontSize, fontName: currentFontName)
            } else { return }
        case .text:
            return
        case .eraser:
            return
        case .eyedropper:
            return
        case .none:
            return
        }
        
        drawingElements.append(element)
    }
    
    private func handleResize(corner: Int, to point: NSPoint) {
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
    
    private func updateControlPoints() {
        guard let rect = selectedRect else { return }
        controlPoints = controlPointRects(for: rect)
        window?.invalidateCursorRects(for: self)
    }

    private func updateToolbar() {
        guard let rect = selectedRect else { return }
        
        let toolbarHeight: CGFloat = 36
        var toolbarY = rect.minY - toolbarHeight / 2
        toolbarY = min(max(4, toolbarY), bounds.maxY - toolbarHeight - 4)

        let toolbarFrame = toolbarFrameForSelection(rect, y: toolbarY)
        toolbarView?.frame = toolbarFrame

        let contentWidth = toolbarContentWidth()
        var xOffset = toolbarGroupStartX(toolbarWidth: toolbarFrame.width, contentWidth: contentWidth)
        if actionButtons.count >= 3 {
            actionButtons[0].frame.origin = NSPoint(x: xOffset, y: 4)
            actionButtons[1].frame.origin = NSPoint(x: xOffset + actionButtonWidth + buttonSpacing, y: 4)
            actionButtons[2].frame.origin = NSPoint(x: xOffset + (actionButtonWidth + buttonSpacing) * 2, y: 4)
        }
        xOffset += (actionButtonWidth + buttonSpacing) * 3
        if separatorViews.count >= 1 {
            separatorViews[0].frame.origin = NSPoint(x: xOffset, y: 8)
        }
        xOffset += separatorWidth + buttonSpacing

        for button in toolButtons {
            button.frame.origin = NSPoint(x: xOffset, y: 4)
            xOffset += toolButtonWidth + buttonSpacing
        }
        if separatorViews.count >= 2 {
            separatorViews[1].frame.origin = NSPoint(x: xOffset, y: 8)
        }
        xOffset += separatorWidth + buttonSpacing
        strokeColorButton?.frame.origin = NSPoint(x: xOffset, y: 4)
        xOffset += toolButtonWidth + buttonSpacing
        fillColorButton?.frame.origin = NSPoint(x: xOffset, y: 4)
        xOffset += toolButtonWidth + buttonSpacing
        lineWidthButton?.frame.origin = NSPoint(x: xOffset, y: 4)
        xOffset += toolButtonWidth + buttonSpacing
        fontSettingsButton?.frame.origin = NSPoint(x: xOffset, y: 4)
        updateColorPickerPosition()
        updateLineWidthPickerPosition()
        updateFontPickerPosition()
        updateFontButtonState()
    }

    private func updateToolButtonStates() {
        toolButtons.forEach { button in
            button.state = .off
            (button as? ToolbarButton)?.isActiveAppearance = false
        }
        if let index = toolButtonTypes.firstIndex(of: currentTool),
           index < toolButtons.count,
           let button = toolButtons[index] as? ToolbarButton {
            button.state = .on
            button.isActiveAppearance = true
        }
        updateFontButtonState()
    }

    private func updateFontButtonState() {
        let enabled = currentTool == .text
        fontSettingsButton?.isEnabled = enabled
        if !enabled {
            hideFontPicker()
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            closeOverlay()
        } else if event.modifierFlags.contains(.command),
                  event.charactersIgnoringModifiers?.lowercased() == "z" {
            undoLastDrawing()
        } else {
            super.keyDown(with: event)
        }
    }
    
    private func normalizedRect(from start: NSPoint, to end: NSPoint) -> NSRect {
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        
        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard currentTool == .none else { return }
        if let rect = selectedRect {
            addCursorRect(rect, cursor: .openHand)
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

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if currentTool == .eraser, let rect = selectedRect, rect.contains(location) {
            hoverEraserIndex = drawingElements.lastIndex(where: { elementHitTest($0, point: location, tolerance: 6) })
            needsDisplay = true
        } else if hoverEraserIndex != nil {
            hoverEraserIndex = nil
            needsDisplay = true
        }
        if currentTool == .none, let rect = selectedRect, rect.contains(location), mode != .dragging, mode != .elementDragging {
            NSCursor.openHand.set()
        }
        super.mouseMoved(with: event)
    }

    private func clearToolbar() {
        toolButtons.forEach { $0.removeFromSuperview() }
        actionButtons.forEach { $0.removeFromSuperview() }
        separatorViews.forEach { $0.removeFromSuperview() }
        strokeColorButton?.removeFromSuperview()
        fillColorButton?.removeFromSuperview()
        lineWidthButton?.removeFromSuperview()
        fontSettingsButton?.removeFromSuperview()
        toolButtons.removeAll()
        toolButtonTypes.removeAll()
        actionButtons.removeAll()
        separatorViews.removeAll()
        strokeColorButton = nil
        fillColorButton = nil
        lineWidthButton = nil
        fontSettingsButton = nil
        hideColorPicker()
        hideLineWidthPicker()
        hideFontPicker()
        toolbarView?.removeFromSuperview()
        toolbarView = nil
    }

    private func toolbarFrameForSelection(_ rect: NSRect, y: CGFloat) -> NSRect {
        let contentWidth = toolbarContentWidth()
        let width = contentWidth + toolbarPadding * 2
        var x = rect.midX - width / 2
        if x + width > bounds.maxX { x = bounds.maxX - width }
        if x < 0 { x = 0 }
        return NSRect(x: x, y: y, width: width, height: 36)
    }

    private func toolbarContentWidth() -> CGFloat {
        let toolCount = 9
        let colorCount = 4
        let actionWidth = actionButtonWidth * 3
        let toolWidth = toolButtonWidth * CGFloat(toolCount)
        let colorWidth = toolButtonWidth * CGFloat(colorCount)
        let separatorsWidth = separatorWidth * 2
        let spacingCount = 3 + toolCount + colorCount + 2
        return actionWidth + toolWidth + colorWidth + separatorsWidth + buttonSpacing * CGFloat(spacingCount)
    }

    private func toolbarGroupStartX(toolbarWidth: CGFloat, contentWidth: CGFloat) -> CGFloat {
        return max(toolbarPadding, (toolbarWidth - contentWidth) / 2)
    }

    private func createSeparator(height: CGFloat) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: separatorWidth, height: height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        return view
    }

    private func clampedPoint(_ point: NSPoint) -> NSPoint {
        let x = min(max(bounds.minX, point.x), bounds.maxX)
        let y = min(max(bounds.minY, point.y), bounds.maxY)
        return NSPoint(x: x, y: y)
    }

    private func clampedPoint(_ point: NSPoint, to rect: NSRect) -> NSPoint {
        let x = min(max(rect.minX, point.x), rect.maxX)
        let y = min(max(rect.minY, point.y), rect.maxY)
        return NSPoint(x: x, y: y)
    }

    private func imageRectForViewRect(_ rect: NSRect) -> CGRect {
        let scaleX = CGFloat(screenImage.width) / bounds.width
        let scaleY = CGFloat(screenImage.height) / bounds.height
        let flippedY = bounds.height - rect.maxY
        return CGRect(
            x: rect.minX * scaleX,
            y: flippedY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
    }

    private func colorAtViewPoint(_ point: NSPoint) -> NSColor? {
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

    private func controlPointRects(for rect: NSRect) -> [NSRect] {
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

    private func eraseElement(at point: NSPoint) {
        let tolerance: CGFloat = 6
        for (index, element) in drawingElements.enumerated().reversed() {
            if elementHitTest(element, point: point, tolerance: tolerance) {
                drawingElements.remove(at: index)
                needsDisplay = true
                return
            }
        }
    }

    private func elementHitTest(_ element: DrawingElement, point: NSPoint, tolerance: CGFloat) -> Bool {
        switch element.type {
        case .pen(let points):
            return polylineHitTest(points: points, point: point, tolerance: tolerance)
        case .line(let start, let end),
             .arrow(let start, let end):
            return distanceToSegment(point, start, end) <= tolerance
        case .rectangle(let rect):
            return rectEdgeHitTest(rect, point: point, tolerance: tolerance)
        case .circle(let rect):
            return ellipseEdgeHitTest(rect, point: point, tolerance: tolerance)
        case .text(let text, let origin):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: fontFromElement(element)
            ]
            let size = NSString(string: text).size(withAttributes: attributes)
            let textRect = NSRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
            return textRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
    }

    private func polylineHitTest(points: [NSPoint], point: NSPoint, tolerance: CGFloat) -> Bool {
        guard points.count > 1 else { return false }
        for idx in 0..<(points.count - 1) {
            if distanceToSegment(point, points[idx], points[idx + 1]) <= tolerance {
                return true
            }
        }
        return false
    }

    private func rectEdgeHitTest(_ rect: NSRect, point: NSPoint, tolerance: CGFloat) -> Bool {
        let topLeft = NSPoint(x: rect.minX, y: rect.maxY)
        let topRight = NSPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = NSPoint(x: rect.minX, y: rect.minY)
        let bottomRight = NSPoint(x: rect.maxX, y: rect.minY)
        return distanceToSegment(point, topLeft, topRight) <= tolerance ||
            distanceToSegment(point, topRight, bottomRight) <= tolerance ||
            distanceToSegment(point, bottomRight, bottomLeft) <= tolerance ||
            distanceToSegment(point, bottomLeft, topLeft) <= tolerance
    }

    private func ellipseEdgeHitTest(_ rect: NSRect, point: NSPoint, tolerance: CGFloat) -> Bool {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2
        let ry = rect.height / 2
        guard rx > 0, ry > 0 else { return false }
        let dx = point.x - center.x
        let dy = point.y - center.y
        let normalized = sqrt((dx * dx) / (rx * rx) + (dy * dy) / (ry * ry))
        return abs(normalized - 1) <= (tolerance / max(rx, ry))
    }

    private func distanceToSegment(_ p: NSPoint, _ a: NSPoint, _ b: NSPoint) -> CGFloat {
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

    private func undoLastDrawing() {
        guard !drawingElements.isEmpty else { return }
        drawingElements.removeLast()
        needsDisplay = true
    }

    private func translateDrawingElements(by delta: NSPoint) {
        guard !drawingElements.isEmpty else { return }
        drawingElements = drawingElements.map { element in
            translateElement(element, by: delta)
        }
    }

    private func translateDrawingElement(at index: Int, by delta: NSPoint) {
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
        case .circle(let rect):
            let newRect = NSRect(
                x: rect.origin.x + delta.x,
                y: rect.origin.y + delta.y,
                width: rect.width,
                height: rect.height
            )
            return DrawingElement(type: .circle(rect: newRect), strokeColor: element.strokeColor, fillColor: element.fillColor, lineWidth: element.lineWidth, fontSize: element.fontSize, fontName: element.fontName)
        case .text(let text, let point):
            let newPoint = NSPoint(x: point.x + delta.x, y: point.y + delta.y)
            return DrawingElement(type: .text(text: text, point: newPoint), strokeColor: element.strokeColor, fillColor: element.fillColor, lineWidth: element.lineWidth, fontSize: element.fontSize, fontName: element.fontName)
        }
    }

    private func toggleColorPicker() {
        hideLineWidthPicker()
        if colorPickerView != nil {
            hideColorPicker()
        } else {
            showColorPicker()
        }
    }

    private func showColorPicker() {
        guard let toolbar = toolbarView else { return }
        let button: NSView?
        switch activeColorTarget {
        case .stroke:
            button = strokeColorButton
        case .fill:
            button = fillColorButton
        }
        guard let anchor = button else { return }

        let swatchSize: CGFloat = 18
        let padding: CGFloat = 8
        let columns = 6
        let colors: [NSColor] = [
            .clear, .white, .black, .systemRed, .systemOrange, .systemYellow,
            .systemGreen, .systemTeal, .systemBlue, .systemIndigo, .systemPurple, .systemPink,
            .systemBrown, .systemGray, .lightGray, .darkGray, .cyan, .magenta
        ]
        let rows = Int(ceil(Double(colors.count) / Double(columns)))
        let pickerWidth = padding * 2 + CGFloat(columns) * swatchSize + CGFloat(columns - 1) * 6
        let pickerHeight = padding * 2 + CGFloat(rows) * swatchSize + CGFloat(rows - 1) * 6

        let (pickerX, pickerY) = pickerOrigin(
            pickerSize: NSSize(width: pickerWidth, height: pickerHeight),
            toolbar: toolbar,
            button: anchor
        )
        
        let picker = NSView(frame: NSRect(x: pickerX, y: pickerY, width: pickerWidth, height: pickerHeight))
        picker.wantsLayer = true
        picker.layer?.cornerRadius = 8
        picker.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.95).cgColor
        picker.layer?.borderWidth = 1
        picker.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        picker.layer?.shadowColor = NSColor.black.cgColor
        picker.layer?.shadowOpacity = 0.35
        picker.layer?.shadowRadius = 8
        picker.layer?.shadowOffset = CGSize(width: 0, height: -2)

        var index = 0
        for row in 0..<rows {
            for col in 0..<columns {
                guard index < colors.count else { break }
                let x = padding + CGFloat(col) * (swatchSize + 6)
                let y = padding + CGFloat(rows - 1 - row) * (swatchSize + 6)
                let swatch = createColorSwatch(color: colors[index], frame: NSRect(x: x, y: y, width: swatchSize, height: swatchSize))
                picker.addSubview(swatch)
                index += 1
            }
        }

        addSubview(picker)
        colorPickerView = picker
    }

    private func hideColorPicker() {
        colorPickerView?.removeFromSuperview()
        colorPickerView = nil
    }

    @objc private func toggleLineWidthPicker() {
        hideColorPicker()
        hideFontPicker()
        if lineWidthPickerView != nil {
            hideLineWidthPicker()
        } else {
            showLineWidthPicker()
        }
    }

    private func showLineWidthPicker() {
        guard let toolbar = toolbarView, let button = lineWidthButton else { return }

        let padding: CGFloat = 10
        let sliderWidth: CGFloat = 140
        let sliderHeight: CGFloat = 16
        let labelHeight: CGFloat = 16
        let totalWidth = padding * 2 + sliderWidth
        let totalHeight = padding * 2 + sliderHeight + 6 + labelHeight

        let (pickerX, pickerY) = pickerOrigin(
            pickerSize: NSSize(width: totalWidth, height: totalHeight),
            toolbar: toolbar,
            button: button
        )

        let picker = NSView(frame: NSRect(x: pickerX, y: pickerY, width: totalWidth, height: totalHeight))
        picker.wantsLayer = true
        picker.layer?.cornerRadius = 8
        picker.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.95).cgColor
        picker.layer?.borderWidth = 1
        picker.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        picker.layer?.shadowColor = NSColor.black.cgColor
        picker.layer?.shadowOpacity = 0.35
        picker.layer?.shadowRadius = 8
        picker.layer?.shadowOffset = CGSize(width: 0, height: -2)

        let slider = NSSlider(value: Double(currentLineWidth), minValue: 1, maxValue: 12, target: self, action: #selector(lineWidthSliderChanged(_:)))
        slider.frame = NSRect(x: padding, y: padding + labelHeight + 6, width: sliderWidth, height: sliderHeight)
        slider.controlSize = .small
        slider.isContinuous = true
        picker.addSubview(slider)

        let label = NSTextField(labelWithString: "Width: \(Int(currentLineWidth))")
        label.frame = NSRect(x: padding, y: padding, width: sliderWidth, height: labelHeight)
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.tag = 1001
        picker.addSubview(label)

        addSubview(picker)
        lineWidthPickerView = picker
    }

    private func hideLineWidthPicker() {
        lineWidthPickerView?.removeFromSuperview()
        lineWidthPickerView = nil
    }

    private func updateLineWidthPickerPosition() {
        guard let picker = lineWidthPickerView, let toolbar = toolbarView, let button = lineWidthButton else { return }
        let (pickerX, pickerY) = pickerOrigin(
            pickerSize: picker.frame.size,
            toolbar: toolbar,
            button: button
        )
        picker.frame.origin = NSPoint(x: pickerX, y: pickerY)
    }

    @objc private func lineWidthSliderChanged(_ sender: NSSlider) {
        currentLineWidth = CGFloat(sender.doubleValue)
        if let label = sender.superview?.viewWithTag(1001) as? NSTextField {
            label.stringValue = "Width: \(Int(currentLineWidth))"
        }
        needsDisplay = true
    }

    @objc private func toggleFontPicker() {
        hideColorPicker()
        hideLineWidthPicker()
        if fontPickerView != nil {
            hideFontPicker()
        } else {
            showFontPicker()
        }
    }

    private func showFontPicker() {
        guard let toolbar = toolbarView, let button = fontSettingsButton else { return }

        let padding: CGFloat = 10
        let width: CGFloat = 180
        let rowHeight: CGFloat = 22
        let sliderHeight: CGFloat = 16
        let totalHeight = padding * 2 + rowHeight + 6 + sliderHeight

        let (pickerX, pickerY) = pickerOrigin(
            pickerSize: NSSize(width: width, height: totalHeight),
            toolbar: toolbar,
            button: button
        )

        let picker = NSView(frame: NSRect(x: pickerX, y: pickerY, width: width, height: totalHeight))
        picker.wantsLayer = true
        picker.layer?.cornerRadius = 8
        picker.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.95).cgColor
        picker.layer?.borderWidth = 1
        picker.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.12).cgColor
        picker.layer?.shadowColor = NSColor.black.cgColor
        picker.layer?.shadowOpacity = 0.35
        picker.layer?.shadowRadius = 8
        picker.layer?.shadowOffset = CGSize(width: 0, height: -2)

        let fontPopup = NSPopUpButton(frame: NSRect(x: padding, y: padding + sliderHeight + 6, width: width - padding * 2, height: rowHeight), pullsDown: false)
        fontPopup.addItems(withTitles: fontChoices.map { $0.label })
        if let index = fontChoices.firstIndex(where: { $0.name == currentFontName }) {
            fontPopup.selectItem(at: index)
        } else {
            fontPopup.selectItem(at: 0)
            currentFontName = fontChoices[0].name
        }
        fontPopup.target = self
        fontPopup.action = #selector(fontNamePicked(_:))
        picker.addSubview(fontPopup)

        let slider = NSSlider(value: Double(currentFontSize), minValue: 10, maxValue: 48, target: self, action: #selector(fontSizeChanged(_:)))
        slider.frame = NSRect(x: padding, y: padding, width: width - padding * 2, height: sliderHeight)
        slider.controlSize = .small
        slider.isContinuous = true
        picker.addSubview(slider)

        addSubview(picker)
        fontPickerView = picker
    }

    private func hideFontPicker() {
        fontPickerView?.removeFromSuperview()
        fontPickerView = nil
    }

    private func updateFontPickerPosition() {
        guard let picker = fontPickerView, let toolbar = toolbarView, let button = fontSettingsButton else { return }
        let (pickerX, pickerY) = pickerOrigin(
            pickerSize: picker.frame.size,
            toolbar: toolbar,
            button: button
        )
        picker.frame.origin = NSPoint(x: pickerX, y: pickerY)
    }

    @objc private func fontNamePicked(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < fontChoices.count else { return }
        let choice = fontChoices[index]
        currentFontName = choice.name
        if let field = activeTextField {
            field.font = currentTextFont()
        }
        needsDisplay = true
    }

    @objc private func fontSizeChanged(_ sender: NSSlider) {
        currentFontSize = CGFloat(sender.doubleValue)
        if let field = activeTextField {
            field.font = currentTextFont()
        }
        needsDisplay = true
    }

    private func updateColorPickerPosition() {
        guard let picker = colorPickerView, let toolbar = toolbarView else { return }
        let button: NSView?
        switch activeColorTarget {
        case .stroke:
            button = strokeColorButton
        case .fill:
            button = fillColorButton
        }
        guard let anchor = button else { return }
        let (pickerX, pickerY) = pickerOrigin(
            pickerSize: picker.frame.size,
            toolbar: toolbar,
            button: anchor
        )
        picker.frame.origin = NSPoint(x: pickerX, y: pickerY)
    }

    private func currentTextFont() -> NSFont {
        if let font = NSFont(name: currentFontName, size: currentFontSize) {
            return font
        }
        return NSFont.systemFont(ofSize: currentFontSize, weight: .semibold)
    }

    private func fontFromElement(_ element: DrawingElement, size: CGFloat? = nil) -> NSFont {
        let targetSize = size ?? element.fontSize
        if let font = NSFont(name: element.fontName, size: targetSize) {
            return font
        }
        return NSFont.systemFont(ofSize: targetSize, weight: .semibold)
    }

    private func pickerOrigin(pickerSize: NSSize, toolbar: NSView, button: NSView) -> (CGFloat, CGFloat) {
        let buttonFrameInView = button.convert(button.bounds, to: self)
        let toolbarFrameInView = toolbar.frame
        let minX = toolbarFrameInView.minX + 4
        let maxX = toolbarFrameInView.maxX - pickerSize.width - 4
        let pickerX = max(minX, min(maxX, buttonFrameInView.midX - pickerSize.width / 2))
        let pickerY = toolbarFrameInView.maxY + 8
        return (pickerX, pickerY)
    }

    private func createColorSwatch(color: NSColor, frame: NSRect) -> NSButton {
        let button = NSButton(frame: frame)
        button.wantsLayer = true
        button.layer?.cornerRadius = 4
        button.layer?.backgroundColor = color.cgColor
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.15).cgColor
        button.isBordered = false
        button.title = ""
        button.target = self
        button.action = #selector(colorPicked(_:))
        if color == .clear {
            let slash = CAShapeLayer()
            let insetRect = frame.insetBy(dx: 3, dy: 3)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: insetRect.minX, y: insetRect.minY))
            path.line(to: NSPoint(x: insetRect.maxX, y: insetRect.maxY))
            slash.path = path.cgPath
            slash.strokeColor = NSColor.systemRed.cgColor
            slash.lineWidth = 2
            button.layer?.addSublayer(slash)
        }
        return button
    }

    private func startTextEntry(at point: NSPoint) {
        activeTextField?.removeFromSuperview()
        activeTextField = nil

        let font = currentTextFont()
        let fieldHeight = ceil(font.ascender - font.descender) + 4
        let fieldOrigin = NSPoint(x: point.x, y: point.y - font.ascender)
        let field = NSTextField(frame: NSRect(x: fieldOrigin.x, y: fieldOrigin.y, width: 200, height: fieldHeight))
        field.delegate = self
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.textColor = currentStrokeColor
        field.font = font
        addSubview(field)
        window?.makeFirstResponder(field)
        activeTextField = field
        activeTextOrigin = point
    }
    
    func controlTextDidEndEditing(_ notification: Notification) {
        finishActiveTextEntry(commit: true)
    }

    private func finishActiveTextEntry(commit: Bool) {
        guard let field = activeTextField else { return }
        if commit {
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let origin = activeTextOrigin, !text.isEmpty {
        let element = DrawingElement(type: .text(text: text, point: origin), strokeColor: currentStrokeColor, fillColor: nil, lineWidth: currentLineWidth, fontSize: currentFontSize, fontName: currentFontName)
        drawingElements.append(element)
            }
        }
        field.removeFromSuperview()
        activeTextField = nil
        activeTextOrigin = nil
        needsDisplay = true
    }

    private func notifySelectionChanged() {
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
        mode = .selecting
        startPoint = nil
        currentPoint = nil
        selectedRect = nil
        controlPoints.removeAll()
        drawingElements.removeAll()
        currentTool = .none
        activeTextField?.removeFromSuperview()
        activeTextField = nil
        activeTextOrigin = nil
        clearToolbar()
        needsDisplay = true
    }
}
