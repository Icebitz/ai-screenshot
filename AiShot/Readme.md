# AiShot (Lightshot Clone)

A macOS screenshot application built with Swift, similar to Lightshot, with region selection, drawing tools, and quick sharing capabilities.

## Features

- **Menu Bar Only**: Runs from the menu bar without showing a dock icon
- **Region Selection**: Click and drag to select any region of the screen
- **Drawing Tools**:
  - Pen (freehand drawing)
  - Line
  - Arrow
  - Rectangle
  - Circle
- **AI Edit**: Prompt-based edits for the selected region (requires API key)
- **Editing Controls**:
  - Move the captured region
  - Resize using corner control points
  - Draw annotations on the screenshot
- **Quick Actions**:
  - Copy to clipboard
  - Save to file
  - Close/cancel
- **Hotkey**: Global shortcut to trigger capture (customizable in Settings)
- **Keyboard Shortcuts**:
  - ESC to cancel selection or close editor

## Requirements

- macOS 26.0 or later
- Xcode 16.0 or later
- Screen Recording permission (requested on first run)

## Setup Instructions

### 1. Open the Project

1. Open Xcode
2. Open `AiShot.xcodeproj`
3. Select the `AiShot` target

### 2. Configure Info.plist

Replace or update your Info.plist with the provided one. Key settings:
- `LSUIElement`: true (hides dock icon)
- `NSScreenCaptureDescription`: Permission description

### 3. Add Required Frameworks

In your Xcode project:
1. Select your project in the navigator
2. Select your target
3. Go to "Frameworks, Libraries, and Embedded Content"
4. Add the following frameworks:
   - `ScreenCaptureKit.framework`

### 4. Configure Capabilities

1. Select your target
2. Go to "Signing & Capabilities"
3. Enable "Hardened Runtime"
4. Under Hardened Runtime, enable:
   - "Disable Library Validation"
   - "Allow DYLD Environment Variables" (for debugging)
5. Ensure the entitlements file is set to `AiShot.entitlements`

### 5. Build and Run

1. Build the project (Cmd+B)
2. Run the app (Cmd+R)
3. On first run, grant Screen Recording permission when prompted
### AI Setup (Optional)

1. Open Settings from the menu bar
2. Add your OpenAI API key
3. Pick an AI model

4. If permission dialog doesn't appear:
   - Go to System Settings > Privacy & Security > Screen Recording
   - Add your app manually

## Usage

### Taking a Screenshot

1. Click the camera icon in the menu bar
2. Select "Take Screenshot..."
3. The screen is captured and displayed as a fixed overlay
4. Click and drag to select a region
5. Press ESC to cancel at any time

### Editing the Selection

Once you've selected a region, you can:

1. **Re-select a region**: Click and drag anywhere outside the current selection to create a new selection
2. **Move the region**: Click and drag inside the selected area (when no tool is active)
3. **Resize**: Click and drag the blue corner points
4. **Draw annotations**:
   - Click a tool button (pen, line, arrow, rectangle, circle)
   - Draw on the screenshot
   - Click the same tool again to deselect and return to move/resize mode

### Tools and Controls

The toolbar appears below the selected region with:

**Drawing Tools**:
- Pen - Freehand drawing
- Line - Straight lines
- Arrow - Arrows with arrowheads
- Rectangle - Rectangles
- Circle - Circles/ellipses

**Action Buttons**:
- **Copy**: Click "Copy" to copy to clipboard
- **Save**: Click "Save" to choose a save location
- **Close**: Click "Close" or press ESC to cancel and close the overlay

## Project Structure

```
AiShot/
├── AiShot.xcodeproj
├── Info.plist
├── AiShot.entitlements
├── Assets.xcassets
└── Modules/
    ├── App/
    │   └── AiShot.swift           # Main app entry point, menu bar setup
    ├── Capture/
    │   └── ScreenshotManager.swift # Screen capture logic
    ├── Overlay/                  # Selection UI, drawing tools, AI prompt
    ├── Settings/                 # Hotkey + AI settings
    └── AI/
        └── OpenAIClient.swift    # Image edit API calls
```

## Architecture

1. **AiShot**: Sets up the menu bar icon and handles app lifecycle
2. **ScreenshotManager**: Manages screen capture using ScreenCaptureKit
3. **OverlayWindow**: Displays full-screen overlay with:
   - Fixed background image (captured screen)
   - Region selection (drag to select)
   - Region editing (move, resize, re-select)
   - Drawing tools (pen, line, arrow, rectangle, circle)
   - Toolbar with tools and action buttons
   - AI prompt for editing the selected region
   - All editing happens in overlay mode without switching windows

## Key Technologies

- **ScreenCaptureKit**: macOS framework for screen capture
- **AppKit**: Native macOS UI framework
- **CGContext**: Core Graphics for drawing and image manipulation

## Troubleshooting

### Screen Recording Permission Not Working

1. Quit the app completely
2. Go to System Settings > Privacy & Security > Screen Recording
3. Remove the app from the list if present
4. Run the app again to re-request permission

### App Doesn't Appear in Menu Bar

- Make sure `LSUIElement` is set to `true` in Info.plist
- Check that the app is running (look in Activity Monitor)

### Drawing Tools Not Working

- Make sure you've clicked a tool button first
- Tools only work inside the captured image area
- Click the tool button again to deselect

### Can't Save Images

- Check file system permissions
- Make sure you have write access to the selected directory

## Future Enhancements

Possible additions:
- Text tool for adding labels
- Blur/pixelate tool for privacy
- Color picker for drawing tools
- Line width adjustment
- Undo/redo functionality
- Upload to cloud services
- Smarter AI mask editing controls
- Image cropping tool
- Magnifying glass during selection

## License

This is a demonstration project. Feel free to modify and use as needed.

## Notes

- The app uses `UserNotifications` for quick feedback notifications
- Screen capture requires ScreenCaptureKit
- The app sets itself as `.accessory` to hide from the dock
- Window levels are set to `.screenSaver` and `.floating` for proper overlay behavior
