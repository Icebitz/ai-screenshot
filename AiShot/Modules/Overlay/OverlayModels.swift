import Cocoa

extension Notification.Name {
    static let overlaySelectionDidChange = Notification.Name("AiShot.OverlaySelectionDidChange")
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
    case move
    case pen
    case line
    case arrow
    case rectangle
    case circle
    case text
    case eraser
    case eyedropper
    case ai
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

enum ToolbarGroupPosition {
    case single
    case first
    case middle
    case last
}

enum SwatchStyle {
    case stroke
    case fill
}
