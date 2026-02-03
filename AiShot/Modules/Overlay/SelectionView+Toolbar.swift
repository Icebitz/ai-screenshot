import Cocoa

extension SelectionView {
    func setupToolbar(for rect: NSRect) {
        clearToolbar()

        // Place toolbar centered on the bottom edge of the selection
        let toolbarHeight: CGFloat = 48
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
        let actionIcons = ["doc.on.doc", "internaldrive", "xmark"]
        let actionSelectors: [Selector] = [#selector(copyToClipboard), #selector(saveImage), #selector(closeOverlay)]
        actionButtons = []
        for (index, icon) in actionIcons.enumerated() {
            let button = createActionButton(icon: icon, x: xOffset, y: 8, action: actionSelectors[index])
            button.groupPosition = groupPosition(for: index, count: actionIcons.count)
            actionButtons.append(button)
            toolbar.addSubview(button)
            xOffset += actionButtonWidth
            if index < actionIcons.count - 1 {
                xOffset += intraGroupSpacing
            }
        }
        xOffset += buttonSpacing
        
        xOffset += buttonSpacing

        // Tool buttons (right)
        let tools: [(String, ToolMode)] = [
            ("arrow.up.and.down.and.arrow.left.and.right", .move),
            ("cursorarrow", .select),
            ("scribble", .pen),
            ("line.diagonal", .line),
            ("arrow.up.right", .arrow),
            ("rectangle", .rectangle),
            ("circle", .ellipse),
            ("textformat", .text),
            ("eraser", .eraser),
            ("sparkles", .ai)
        ]
        
        toolButtonTypes = tools.map { $0.1 }
        for (index, (icon, tool)) in tools.enumerated() {
            let button = createToolButton(icon: icon, tool: tool, x: xOffset, y: 8)
            button.groupPosition = groupPosition(for: index, count: tools.count)
            toolButtons.append(button)
            toolbar.addSubview(button)
            xOffset += toolButtonWidth
            if index < tools.count - 1 {
                xOffset += intraGroupSpacing
            }
        }
        xOffset += buttonSpacing
        
        xOffset += buttonSpacing

        let strokeButton = ColorSwatchButton(frame: NSRect(x: xOffset, y: 8, width: toolButtonWidth, height: 32))
        strokeButton.title = ""
        strokeButton.image = nil
        strokeButton.isBordered = false
        strokeButton.swatchColor = currentStrokeColor
        strokeButton.target = self
        strokeButton.action = #selector(openStrokeColorPicker)
        strokeButton.groupPosition = ToolbarGroupPosition.first
        strokeButton.swatchStyle = .stroke
        strokeColorButton = strokeButton
        toolbar.addSubview(strokeButton)
        xOffset += toolButtonWidth + intraGroupSpacing

        let fillButton = ColorSwatchButton(frame: NSRect(x: xOffset, y: 8, width: toolButtonWidth, height: 32))
        fillButton.title = ""
        fillButton.image = nil
        fillButton.isBordered = false
        fillButton.swatchColor = currentFillColor ?? .clear
        fillButton.target = self
        fillButton.action = #selector(openFillColorPicker)
        fillButton.groupPosition = ToolbarGroupPosition.middle
        fillButton.swatchStyle = .fill
        fillColorButton = fillButton
        toolbar.addSubview(fillButton)
        xOffset += toolButtonWidth + intraGroupSpacing

        let widthButton = createIconButton(icon: "lineweight", x: xOffset, y: 8)
        widthButton.target = self
        widthButton.action = #selector(toggleLineWidthPicker)
        widthButton.isActiveAppearance = false
        widthButton.groupPosition = ToolbarGroupPosition.middle
        lineWidthButton = widthButton
        toolbar.addSubview(widthButton)
        xOffset += toolButtonWidth + intraGroupSpacing

        let fontButton = createIconButton(icon: "textformat.size", x: xOffset, y: 8)
        fontButton.target = self
        fontButton.action = #selector(toggleFontPicker)
        fontButton.isActiveAppearance = false
        fontButton.groupPosition = ToolbarGroupPosition.last
        fontSettingsButton = fontButton
        toolbar.addSubview(fontButton)

        updateGroupBorders()
    }

    func updateToolbar() {
        guard let rect = selectedRect else { return }
        
        let toolbarHeight: CGFloat = 48
        var toolbarY = rect.minY - toolbarHeight / 2
        toolbarY = min(max(4, toolbarY), bounds.maxY - toolbarHeight - 4)

        let toolbarFrame = toolbarFrameForSelection(rect, y: toolbarY)
        toolbarView?.frame = toolbarFrame

        let contentWidth = toolbarContentWidth()
        var xOffset = toolbarGroupStartX(toolbarWidth: toolbarFrame.width, contentWidth: contentWidth)
        if actionButtons.count >= 3 {
            for (index, button) in actionButtons.enumerated() {
                button.frame.origin = NSPoint(x: xOffset, y: 8)
                xOffset += actionButtonWidth
                if index < actionButtons.count - 1 {
                    xOffset += intraGroupSpacing
                }
            }
        }
        xOffset += buttonSpacing
        xOffset += buttonSpacing

        for (index, button) in toolButtons.enumerated() {
            button.frame.origin = NSPoint(x: xOffset, y: 8)
            xOffset += toolButtonWidth
            if index < toolButtons.count - 1 {
                xOffset += intraGroupSpacing
            }
        }
        xOffset += buttonSpacing
        xOffset += buttonSpacing
        strokeColorButton?.frame.origin = NSPoint(x: xOffset, y: 8)
        xOffset += toolButtonWidth + intraGroupSpacing
        fillColorButton?.frame.origin = NSPoint(x: xOffset, y: 8)
        xOffset += toolButtonWidth + intraGroupSpacing
        lineWidthButton?.frame.origin = NSPoint(x: xOffset, y: 8)
        xOffset += toolButtonWidth + intraGroupSpacing
        fontSettingsButton?.frame.origin = NSPoint(x: xOffset, y: 8)
        updateGroupBorders()
        updateColorPickerPosition()
        updateLineWidthPickerPosition()
        updateFontPickerPosition()
        updateFontButtonState()
        updateAIPromptVisibility()
    }

    private func createToolButton(icon: String, tool: ToolMode, x: CGFloat, y: CGFloat) -> ToolbarButton {
        let button = ToolbarButton(frame: NSRect(x: x, y: y, width: toolButtonWidth, height: 32))
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
        button.isActiveAppearance = (tool == .move)
        
        return button
    }

    func createIconButton(icon: String, x: CGFloat, y: CGFloat) -> ToolbarButton {
        let button = ToolbarButton(frame: NSRect(x: x, y: y, width: toolButtonWidth, height: 32))
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
    
    private func createActionButton(icon: String, x: CGFloat, y: CGFloat, action: Selector) -> ToolbarButton {
        let button = ToolbarButton(frame: NSRect(x: x, y: y, width: actionButtonWidth, height: 32))
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
        guard let senderButton = sender as? ToolbarButton else { return }
        if let index = toolButtons.firstIndex(where: { $0 === senderButton }),
           index < toolButtonTypes.count {
            let nextTool = toolButtonTypes[index]
            if currentTool == ToolMode.text, nextTool != .text {
                finishActiveTextEntry(commit: true)
            }
            if currentTool == ToolMode.eraser, nextTool != .eraser {
                hoverEraserIndex = nil
            }
            if currentTool == .ai, nextTool != .ai {
                aiEditRect = nil
                aiIsSelectingEditRect = false
            }
            currentTool = nextTool
            
            // Update button states
            updateToolButtonStates()
            
            needsDisplay = true
        }
    }

    private func toolbarFrameForSelection(_ rect: NSRect, y: CGFloat) -> NSRect {
        let contentWidth = toolbarContentWidth()
        let width = contentWidth + toolbarPadding * 2
        var x = rect.midX - width / 2
        if x + width > bounds.maxX { x = bounds.maxX - width }
        if x < 0 { x = 0 }
        return NSRect(x: x, y: y, width: width, height: 48)
    }

    private func toolbarContentWidth() -> CGFloat {
        let toolCount = 10
        let colorCount = 4
        let actionCount = 3
        let actionWidth = actionButtonWidth * CGFloat(actionCount)
        let toolWidth = toolButtonWidth * CGFloat(toolCount)
        let colorWidth = toolButtonWidth * CGFloat(colorCount)
        let intraSpacingCount = max(0, actionCount - 1) + max(0, toolCount - 1) + max(0, colorCount - 1)
        let groupSpacingCount = 4
        return actionWidth + toolWidth + colorWidth
            + intraGroupSpacing * CGFloat(intraSpacingCount)
            + buttonSpacing * CGFloat(groupSpacingCount)
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

    private func createGroupBorder(for views: [NSView]) -> NSView? {
        guard !views.isEmpty else { return nil }
        let frames = views.map { $0.frame }
        let minX = frames.map { $0.minX }.min() ?? 0
        let maxX = frames.map { $0.maxX }.max() ?? 0
        let minY = frames.map { $0.minY }.min() ?? 0
        let maxY = frames.map { $0.maxY }.max() ?? 0
        let borderView = NSView(frame: NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
        borderView.wantsLayer = true
        borderView.layer?.cornerRadius = 6
        borderView.layer?.borderWidth = 1
        borderView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.10).cgColor
        borderView.layer?.backgroundColor = NSColor.clear.cgColor
        return borderView
    }

    private func updateGroupBorders() {
        groupBorderViews.forEach { $0.removeFromSuperview() }
        groupBorderViews.removeAll()
        guard let toolbar = toolbarView else { return }

        if let border = createGroupBorder(for: actionButtons) {
            toolbar.addSubview(border, positioned: .below, relativeTo: actionButtons.first)
            groupBorderViews.append(border)
        }
        if let border = createGroupBorder(for: toolButtons) {
            toolbar.addSubview(border, positioned: .below, relativeTo: toolButtons.first)
            groupBorderViews.append(border)
        }
        if let stroke = strokeColorButton,
           let fill = fillColorButton,
           let width = lineWidthButton,
           let font = fontSettingsButton,
           let border = createGroupBorder(for: [stroke, fill, width, font]) {
            toolbar.addSubview(border, positioned: .below, relativeTo: stroke)
            groupBorderViews.append(border)
        }
    }

    private func makeSwatchLabel(text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        label.textColor = NSColor.white.withAlphaComponent(0.9)
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBordered = false
        label.sizeToFit()
        label.frame = NSRect(x: 4, y: 4, width: 12, height: 12)
        return label
    }

    private func groupPosition(for index: Int, count: Int) -> ToolbarGroupPosition {
        if count <= 1 { return .single }
        if index == 0 { return .first }
        if index == count - 1 { return .last }
        return .middle
    }
}
