import Cocoa

extension Notification.Name {
    static let overlaySelectionDidChange = Notification.Name("AiShot.OverlaySelectionDidChange")
}

enum SelectionMode {
    case creating       // Dragging to create selection
    case active         // Selection exists, tools visible
    case moving         // Moving the selection
    case resizing       // Resizing the selection
    case drawing        // Drawing shapes/lines
    case movingElement  // Moving a drawn element
    case creatingText   // Dragging to create text area
    case editingText    // Editing text
    case resizingTextArea  // Resizing text area via control points
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
