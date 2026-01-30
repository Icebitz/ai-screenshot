import Cocoa

extension SelectionView {
    @objc func toggleColorPicker() {
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
            .systemBrown, .systemGray, .lightGray, .darkGray, .cyan
        ]
        let totalItems = colors.count + 1
        let rows = Int(ceil(Double(totalItems) / Double(columns)))
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
                guard index < totalItems else { break }
                let x = padding + CGFloat(col) * (swatchSize + 6)
                let y = padding + CGFloat(rows - 1 - row) * (swatchSize + 6)
                if index == colors.count {
                    let eyedropper = createEyedropperSwatch(frame: NSRect(x: x, y: y, width: swatchSize, height: swatchSize))
                    picker.addSubview(eyedropper)
                } else {
                    let swatch = createColorSwatch(color: colors[index], frame: NSRect(x: x, y: y, width: swatchSize, height: swatchSize))
                    picker.addSubview(swatch)
                }
                index += 1
            }
        }

        addSubview(picker)
        colorPickerView = picker
    }

    func hideColorPicker() {
        colorPickerView?.removeFromSuperview()
        colorPickerView = nil
    }

    @objc func toggleLineWidthPicker() {
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

    func hideLineWidthPicker() {
        lineWidthPickerView?.removeFromSuperview()
        lineWidthPickerView = nil
    }

    func updateLineWidthPickerPosition() {
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

    @objc func toggleFontPicker() {
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
        styleFontPopup(fontPopup)
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

    func hideFontPicker() {
        fontPickerView?.removeFromSuperview()
        fontPickerView = nil
    }

    func updateFontPickerPosition() {
        guard let picker = fontPickerView, let toolbar = toolbarView, let button = fontSettingsButton else { return }
        let (pickerX, pickerY) = pickerOrigin(
            pickerSize: picker.frame.size,
            toolbar: toolbar,
            button: button
        )
        picker.frame.origin = NSPoint(x: pickerX, y: pickerY)
    }

    private func styleFontPopup(_ popup: NSPopUpButton) {
        popup.appearance = NSAppearance(named: .vibrantDark)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white
        ]
        if let items = popup.menu?.items {
            for item in items {
                item.attributedTitle = NSAttributedString(string: item.title, attributes: attributes)
            }
        }
        if let selectedItem = popup.selectedItem {
            selectedItem.attributedTitle = NSAttributedString(string: selectedItem.title, attributes: attributes)
        }
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

    func updateColorPickerPosition() {
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
            button.layer?.backgroundColor = NSColor.clear.cgColor
            let checkerLayer = CALayer()
            checkerLayer.frame = button.bounds.insetBy(dx: 1, dy: 1)
            checkerLayer.contents = makeCheckerboardImage(size: checkerLayer.bounds.size, squareSize: 4)
            checkerLayer.contentsGravity = .resize
            button.layer?.insertSublayer(checkerLayer, at: 0)
        }
        return button
    }

    private func createEyedropperSwatch(frame: NSRect) -> NSButton {
        let button = NSButton(frame: frame)
        button.wantsLayer = true
        button.layer?.cornerRadius = 4
        button.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.95).cgColor
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.15).cgColor
        button.isBordered = false
        button.title = ""
        button.image = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.contentTintColor = .white
        button.target = self
        button.action = #selector(activateEyedropperFromPicker)
        return button
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
}
