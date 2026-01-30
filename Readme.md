# AiShot

A macOS screenshot tool built with Swift that focuses on AI-powered region edits alongside fast capture and annotation.

## Features

- Menu bar app
- Fast region capture
- AI edit for a selected area (API key required)
- Simple drawing tools
- Copy, save, or cancel quickly
- Custom hotkey

## Requirements

- macOS 26.0 or later
- Xcode 16.0 or later
- Screen Recording permission (requested on first run)

## Version

- App version: 0.1.0
- Build: 1

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
├── Assets.xcassets
└── Modules/ (app, capture, overlay, settings, AI)
```

### Modules

- App: app entry and menu bar setup
- Capture: screen capture pipeline
- Overlay: selection UI, tools, and AI prompt
- Settings: hotkey and AI preferences
- AI: OpenAI image edit client

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

- Better AI mask controls
- More AI models and presets
- Privacy tools (blur/pixelate)
- Manual editing tools
- Share to cloud

## License

This is a demonstration project. Feel free to modify and use as needed.

## Notes

- The app uses `UserNotifications` for quick feedback notifications
- Screen capture requires ScreenCaptureKit
- The app sets itself as `.accessory` to hide from the dock
- Window levels are set to `.screenSaver` and `.floating` for proper overlay behavior
