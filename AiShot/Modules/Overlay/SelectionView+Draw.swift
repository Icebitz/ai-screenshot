import Cocoa

extension SelectionView {
    func drawSelectionArea(_ rect: NSRect, in context: CGContext) {
        context.setBlendMode(.normal)
        let imageRect = imageRectForViewRect(rect)
        
        // Draw the screen image in the selection area
        if let aiResultImage {
            context.draw(aiResultImage, in: rect)
        } else if let croppedImage = screenImage.cropping(to: imageRect) {
            context.draw(croppedImage, in: rect)
        }
        // Draw selection border
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)
    }

    func drawAIEditRect(_ rect: NSRect, in context: CGContext) {
        context.saveGState()
        context.setBlendMode(.difference)
        context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.7).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.stroke(rect)
        context.restoreGState()
    }

    func drawAIProcessingBorder(_ rect: NSRect, in context: CGContext) {
        context.saveGState()
        context.setBlendMode(.normal)
        context.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.7).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: aiDashPhase, lengths: aiDashPattern)
        context.stroke(rect.insetBy(dx: 1, dy: 1))
        context.restoreGState()
    }

    func drawFullScreenImage(in context: CGContext) {
        context.draw(screenImage, in: bounds)
    }

    func drawDimOverlay(in context: CGContext) {
        context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        context.fill(bounds)
    }
    
    func drawSizeLabel(for rect: NSRect, in context: CGContext) {
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
    
    func drawElement(_ element: DrawingElement, in context: CGContext) {
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
            
        case .ellipse(let rect):
            if let fillColor = element.fillColor {
                context.setFillColor(fillColor.cgColor)
                context.fillEllipse(in: rect)
            }
            context.strokeEllipse(in: rect)
            
        case .text(let text, let rect):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: fontFromElement(element),
                .foregroundColor: element.strokeColor
            ]
            let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
            (text as NSString).draw(with: rect, options: options, attributes: attributes, context: nil)
        }
    }

    func drawElementHighlights(in context: CGContext) {
        if let index = selectedElementIndex, index < drawingElements.count {
            drawElementBoundingRect(drawingElements[index], in: context, color: NSColor.systemBlue)
        }
    }

    private func drawElementGlow(_ element: DrawingElement, in context: CGContext, color: NSColor) {
        context.saveGState()
        context.setShadow(offset: .zero, blur: 6, color: color.cgColor)
        context.setStrokeColor(color.cgColor)
        let lineWidth = max(1, element.lineWidth)
        context.setLineWidth(lineWidth)
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
            drawArrow(from: start, to: end, in: context, color: color, lineWidth: lineWidth)
        case .rectangle(let rect):
            context.stroke(rect)
        case .ellipse(let rect):
            context.strokeEllipse(in: rect)
        case .text(let text, let rect):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: fontFromElement(element),
                .foregroundColor: color
            ]
            let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
            (text as NSString).draw(with: rect, options: options, attributes: attributes, context: nil)
        }
        context.restoreGState()
    }

    private func drawElementTint(_ element: DrawingElement, in context: CGContext, color: NSColor) {
        context.saveGState()
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
        case .ellipse(let rect):
            context.strokeEllipse(in: rect.insetBy(dx: -2, dy: -2))
        case .text(let text, let rect):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: fontFromElement(element),
                .foregroundColor: color
            ]
            let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
            (text as NSString).draw(with: rect, options: options, attributes: attributes, context: nil)
        }
        context.restoreGState()
    }

    private func drawElementBoundingRect(_ element: DrawingElement, in context: CGContext, color: NSColor) {
        let rect: NSRect?
        switch element.type {
        case .pen(let points):
            guard let first = points.first else { return }
            var minX = first.x
            var minY = first.y
            var maxX = first.x
            var maxY = first.y
            for point in points.dropFirst() {
                minX = min(minX, point.x)
                minY = min(minY, point.y)
                maxX = max(maxX, point.x)
                maxY = max(maxY, point.y)
            }
            rect = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        case .line(let start, let end), .arrow(let start, let end):
            let minX = min(start.x, end.x)
            let minY = min(start.y, end.y)
            let maxX = max(start.x, end.x)
            let maxY = max(start.y, end.y)
            rect = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        case .rectangle(let rectValue), .ellipse(let rectValue):
            rect = rectValue
        case .text(_, let textRect):
            rect = textRect
        }
        guard let baseRect = rect else { return }
        let expanded = baseRect.insetBy(dx: -4, dy: -4)
        context.saveGState()
        context.setStrokeColor(color.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [1.2, 2.4])
        context.stroke(expanded)
        context.restoreGState()
    }

    private func elementStrokeColor(_ element: DrawingElement) -> NSColor {
        switch element.type {
        case .pen, .line, .arrow, .rectangle, .ellipse, .text:
            return element.strokeColor
        }
    }

    private func invertedColor(_ color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.deviceRGB) else {
            return NSColor.white
        }
        return NSColor(
            calibratedRed: 1.0 - rgb.redComponent,
            green: 1.0 - rgb.greenComponent,
            blue: 1.0 - rgb.blueComponent,
            alpha: 0.9
        )
    }
    
    func drawCurrentDrawing(in context: CGContext) {
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
        case .ellipse:
            if let start = drawingStartPoint, let current = currentDrawingPoints.last {
                let rect = normalizedRect(from: start, to: current)
                if let fillColor = currentFillColor {
                    context.setFillColor(fillColor.cgColor)
                    context.fillEllipse(in: rect)
                }
                context.strokeEllipse(in: rect)
            }
        case .none, .text, .eraser, .eyedropper, .move, .select, .ai:
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

    func drawControlPoints(for rect: NSRect, in context: CGContext, size: CGFloat = 12) {
        let points = controlPointRects(for: rect, size: size)
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

    func drawCenterGuides(for rect: NSRect, in context: CGContext) {
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

    func renderFinalImage(for rect: NSRect) -> CGImage {
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
        
        // Draw base image (AI result if available, otherwise cropped screen)
        if let aiResultImage, aiResultImage.width == width, aiResultImage.height == height {
            context.draw(aiResultImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        } else if let croppedImage = screenImage.cropping(to: imageRect) {
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
            
        case .ellipse(let rect):
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
            
        case .text(let text, let textRect):
            let attributes: [NSAttributedString.Key: Any] = [
                .font: fontFromElement(element, size: element.fontSize * scaleY),
                .foregroundColor: element.strokeColor
            ]
            let adjustedRect = CGRect(
                x: (textRect.origin.x - offset.x) * scaleX,
                y: (textRect.origin.y - offset.y) * scaleY,
                width: textRect.width * scaleX,
                height: textRect.height * scaleY
            )
            let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
            let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphicsContext
            (text as NSString).draw(with: adjustedRect, options: options, attributes: attributes, context: nil)
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
