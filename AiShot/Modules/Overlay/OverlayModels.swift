import Cocoa

extension Notification.Name {
    static let overlaySelectionDidChange = Notification.Name("AiShot.OverlaySelectionDidChange")
}

enum ActionMode {
    case creating
    case editing
    case moving
    case resizing
    case selecting
    case selected
    case dragging
    case drawing
    case elementDragging
}

enum ToolMode {
    case none
    case move
    case select
    case pen
    case line
    case arrow
    case rectangle
    case ellipse
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
        case ellipse(rect: NSRect)
        case text(text: String, rect: NSRect)
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
