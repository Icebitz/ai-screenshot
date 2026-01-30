import Cocoa

class ToolbarButton: NSButton {
    var baseColor = NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.26, alpha: 1.0)
    var accentColor: NSColor?
    var isActiveAppearance = false {
        didSet { needsDisplay = true }
    }
    var groupPosition: ToolbarGroupPosition = .single {
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

        applyGroupCorners(to: gradientLayer)
        applyGroupCorners(to: layer)
        layer.borderWidth = 0
        layer.borderColor = NSColor.clear.cgColor
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.shadowOffset = .zero
    }

    private func applyGroupCorners(to layer: CALayer) {
        let radius: CGFloat = 6
        switch groupPosition {
        case .single:
            layer.cornerRadius = radius
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        case .first:
            layer.cornerRadius = radius
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        case .middle:
            layer.cornerRadius = 0
        case .last:
            layer.cornerRadius = radius
            layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }
}

final class ColorSwatchButton: ToolbarButton {
    var swatchColor: NSColor = .red {
        didSet { needsDisplay = true }
    }
    var swatchStyle: SwatchStyle = .fill {
        didSet { needsDisplay = true }
    }

    private let indicatorLayer = CALayer()
    private let checkerLayer = CALayer()

    override var isHighlighted: Bool {
        didSet { alphaValue = isHighlighted ? 0.8 : 1.0 }
    }

    override func updateLayer() {
        super.updateLayer()
        guard let layer = layer else { return }

        if indicatorLayer.superlayer == nil {
            layer.addSublayer(indicatorLayer)
        }
        if checkerLayer.superlayer == nil {
            layer.insertSublayer(checkerLayer, below: indicatorLayer)
        }
        indicatorLayer.frame = indicatorFrame()
        indicatorLayer.cornerRadius = 2
        indicatorLayer.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.2).cgColor
        switch swatchStyle {
        case .stroke:
            indicatorLayer.backgroundColor = NSColor.clear.cgColor
            indicatorLayer.borderWidth = 2
            indicatorLayer.borderColor = swatchColor.cgColor
        case .fill:
            indicatorLayer.backgroundColor = swatchColor.cgColor
            indicatorLayer.borderWidth = 1
            indicatorLayer.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.2).cgColor
        }

        if swatchColor == .clear {
            checkerLayer.frame = indicatorFrame()
            checkerLayer.cornerRadius = 2
            checkerLayer.contents = makeCheckerboardImage(size: checkerLayer.bounds.size, squareSize: 4)
            checkerLayer.isHidden = false
            indicatorLayer.backgroundColor = NSColor.clear.cgColor
        } else {
            checkerLayer.isHidden = true
            checkerLayer.contents = nil
        }
    }

    override func layout() {
        super.layout()
        indicatorLayer.frame = indicatorFrame()
        checkerLayer.frame = indicatorFrame()
    }

    private func indicatorFrame() -> CGRect {
        return bounds.insetBy(dx: 6, dy: 6)
    }

    private func makeCheckerboardImage(size: NSSize, squareSize: CGFloat) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let light = NSColor(calibratedWhite: 1.0, alpha: 0.6)
        let dark = NSColor(calibratedWhite: 0.75, alpha: 0.6)
        let cols = Int(ceil(size.width / squareSize))
        let rows = Int(ceil(size.height / squareSize))
        for row in 0..<rows {
            for col in 0..<cols {
                let color = (row + col) % 2 == 0 ? light : dark
                color.setFill()
                let rect = NSRect(
                    x: CGFloat(col) * squareSize,
                    y: CGFloat(row) * squareSize,
                    width: squareSize,
                    height: squareSize
                )
                rect.fill()
            }
        }
        image.unlockFocus()
        return image
    }

    private func applyGroupCorners(to layer: CALayer) {
        let radius: CGFloat = 6
        switch groupPosition {
        case .single:
            layer.cornerRadius = radius
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        case .first:
            layer.cornerRadius = radius
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        case .middle:
            layer.cornerRadius = 0
        case .last:
            layer.cornerRadius = radius
            layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        }
    }
}
