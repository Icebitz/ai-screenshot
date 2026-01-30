import Cocoa

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
