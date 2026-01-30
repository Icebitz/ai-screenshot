import Cocoa
import UniformTypeIdentifiers
import ImageIO

extension SelectionView {
    private func buildAIPrompt(userText: String) -> String {
        let prompt = "You are editing an image.\n\nTask:\n\(userText)"
        let constraints = "STRICT CONSTRAINTS:\n- Maintain original style, lighting, and perspective.\n- Blend edits naturally.\n- Keep the original image as close as possible."

        return "\(prompt)\n\n\(constraints)"
    }

    private func pngData(for image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func maskPNGData(for selectedRect: NSRect) -> Data? {
        let baseImageRect = imageRectForViewRect(selectedRect)
        let width = Int(baseImageRect.width)
        let height = Int(baseImageRect.height)
        guard width > 0, height > 0 else { return nil }

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
            return nil
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let maskImage = context.makeImage() else { return nil }
        return pngData(for: maskImage)
    }

    func showAIPrompt() {
        if aiPromptView != nil { return }
        let promptView = NSVisualEffectView()
        promptView.material = .hudWindow
        promptView.blendingMode = .withinWindow
        promptView.state = .active
        promptView.appearance = NSAppearance(named: .vibrantDark)
        promptView.wantsLayer = true
        promptView.layer?.cornerRadius = 8
        promptView.layer?.borderWidth = 1
        promptView.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.10).cgColor
        promptView.layer?.shadowColor = NSColor.black.cgColor
        promptView.layer?.shadowOpacity = 0.35
        promptView.layer?.shadowRadius = 8
        promptView.layer?.shadowOffset = CGSize(width: 0, height: -2)

        let field = NSTextField(string: "")
        field.placeholderString = ""
        field.isBordered = false
        field.drawsBackground = false
        field.textColor = .white
        field.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        field.focusRingType = .none
        field.delegate = self
        aiPromptField = field

        let sendButton = createIconButton(icon: "paperplane.fill", x: 0, y: 4)
        sendButton.target = self
        sendButton.action = #selector(sendAIPrompt)
        sendButton.groupPosition = ToolbarGroupPosition.single
        aiSendButton = sendButton

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.isDisplayedWhenStopped = false
        aiSendSpinner = spinner

        promptView.addSubview(field)
        promptView.addSubview(sendButton)
        promptView.addSubview(spinner)
        aiPromptView = promptView
        addSubview(promptView)
        updateSendState()
    }

    func hideAIPrompt() {
        aiPromptView?.removeFromSuperview()
        aiPromptView = nil
        aiPromptField = nil
        aiSendButton = nil
        aiSendSpinner = nil
    }

    private func aiPromptWidth(for rect: NSRect) -> CGFloat {
        let clamped = min(max(aiPromptMinWidth, rect.width), aiPromptMaxWidth)
        return min(clamped, max(160, bounds.width - 8))
    }

    func updateAIPromptPosition() {
        guard let rect = selectedRect, let promptView = aiPromptView else { return }
        let width = aiPromptWidth(for: rect)
        let height = aiPromptHeight

        var x = rect.midX - width / 2
        x = min(max(4, x), bounds.maxX - width - 4)

        var y = rect.maxY - 60
        if y + height > bounds.maxY - 4 {
            y = rect.maxY - height - 4
        }
        y = min(max(4, y), bounds.maxY - height - 4)

        promptView.frame = NSRect(x: x, y: y, width: width, height: height)

        let padding: CGFloat = 8
        let buttonWidth: CGFloat = toolButtonWidth
        let fieldWidth = max(
            80,
            width - padding * 2 - buttonWidth
        )
        let fieldHeight: CGFloat = 20
        let fieldY: CGFloat = 8
        let buttonsY: CGFloat = 4
        aiPromptField?.frame = NSRect(x: padding, y: fieldY, width: fieldWidth, height: fieldHeight)
        let sendX = padding + fieldWidth
        let sendFrame = NSRect(x: sendX, y: buttonsY, width: buttonWidth, height: 28)
        aiSendButton?.frame = sendFrame
        aiSendSpinner?.frame = NSRect(
            x: sendFrame.midX - 8,
            y: sendFrame.midY - 8,
            width: 16,
            height: 16
        )
    }

    @objc func sendAIPrompt() {
        guard let field = aiPromptField, let selectedRect = selectedRect else {
            updateAIStatus("AI: select a region first")
            return
        }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = SettingsStore.apiKeyValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            updateAIStatus("AI: enter a prompt")
            updateSendState()
            return
        }
        guard !apiKey.isEmpty else {
            updateAIStatus("AI: add API key in Settings")
            updateSendState()
            return
        }
        let prompt = buildAIPrompt(userText: text)
        let finalImage = renderFinalImage(for: selectedRect)
        guard let imageData = pngData(for: finalImage) else {
            updateAIStatus("AI: failed to encode image")
            updateSendState()
            return
        }
        guard let maskData = maskPNGData(for: selectedRect) else {
            updateAIStatus("AI: failed to encode mask")
            updateSendState()
            return
        }
        aiIsSendingPrompt = true
        updateSendState()
        updateAIStatus("AI: processing...")
        Task { [weak self] in
            do {
                let model = SettingsStore.aiModelValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let resultImage = try await OpenAIClient.editImage(
                    apiKey: apiKey,
                    model: model,
                    prompt: prompt,
                    imageData: imageData,
                    maskData: maskData
                )
                await MainActor.run {
                    self?.aiResultImage = resultImage
                    self?.aiIsSendingPrompt = false
                    self?.aiEditRect = nil
                    self?.aiIsSelectingEditRect = false
                    self?.aiPromptField?.stringValue = ""
                    self?.updateSendState()
                    self?.updateAIStatus("AI: done")
                    self?.needsDisplay = true
                }
            } catch {
                await MainActor.run {
                    self?.aiIsSendingPrompt = false
                    self?.updateSendState()
                    self?.updateAIStatus("AI: processing failed")
                }
            }
        }
    }

    func updateSendState() {
        let isSending = aiIsSendingPrompt
        let promptText = aiPromptField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasPrompt = !promptText.isEmpty
        let hasApiKey = !SettingsStore.apiKeyValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        aiSendButton?.isEnabled = !isSending && hasPrompt && hasApiKey
        aiSendButton?.alphaValue = (isSending || !hasPrompt || !hasApiKey) ? 0.4 : 1.0
        aiPromptField?.isEditable = !isSending
        aiPromptField?.isEnabled = !isSending
        if isSending {
            aiSendSpinner?.startAnimation(nil)
        } else {
            aiSendSpinner?.stopAnimation(nil)
        }
    }

    private func updateAIStatus(_ text: String?) {
        _ = text
    }
}
