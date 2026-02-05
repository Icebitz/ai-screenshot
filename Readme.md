# AiShot

AiShot is a **lightshot-style** macOS menu bar screenshot tool built with Swift. It brings the familiar lightshot workflow to Mac: fast region capture, lightshot-style selection overlay, and optional AI-powered edits for selected areas.

![AiShot Screenshot](screenshot.png)

## Features

- Menu bar app (no Dock icon)
- Lightshot-style fast region capture with a fixed overlay
- Move, resize, and re-select regions (lightshot workflow)
- Lightshot-inspired drawing tools: pen, line, arrow, rectangle, circle
- Copy, save, or cancel quickly
- Custom hotkey
- Optional AI edit for a selected area (API key required)—beyond classic lightshot
- Update check notifications (optional)

## Requirements

- macOS 14.6 or later
- Screen Recording permission (requested on first run)

## Installation

Install the latest release to `/Applications`:

```bash
curl -fsSL https://raw.githubusercontent.com/Icebitz/ai-screenshot/main/scripts/install.sh | bash
```

The script downloads the AiShot zip from [GitHub releases](https://github.com/Icebitz/ai-screenshot/releases), extracts it, installs to `/Applications`, removes Gatekeeper quarantine, and launches the app. Requires `curl`, `unzip`, and macOS.

## Version

- App version: 0.1.0
- Build: 1

To sync these values with `AiShot/Info.plist`, run:

```bash
scripts/update_readme_version.sh
```

## Setup Instructions

### 1. Open the Project

Open `AiShot.xcodeproj`, select the `AiShot` target.

### 2. Configure Info.plist

Replace or update your Info.plist with the provided one. Key settings:
- `LSUIElement`: true (hides dock icon)
- `NSScreenCaptureDescription`: Permission description

### 3. Add Required Frameworks

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
4. If the permission dialog doesn't appear:
   - Go to System Settings > Privacy & Security > Screen Recording
   - Add your app manually

## Usage

### Taking a Screenshot (Lightshot-style)

1. Click the camera icon in the menu bar
2. Select "Take Screenshot..."
3. The screen is captured and displayed as a lightshot-style fixed overlay
4. Click and drag to select a region (classic lightshot selection)
5. Press ESC to cancel at any time

### Editing the Selection

Once you've selected a region lightshot-style, you can:

1. **Re-select a region**: Click and drag anywhere outside the current selection to create a new selection
2. **Move the region**: Click and drag inside the selected area (when no tool is active)
3. **Resize**: Click and drag the blue corner points
4. **Draw annotations**:
   - Click a tool button (pen, line, arrow, rectangle, circle)
   - Draw on the screenshot
   - Click the same tool again to deselect and return to move/resize mode

### Tools and Controls

The lightshot-style toolbar appears below the selected region with:

**Drawing Tools** (lightshot-inspired):
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
├── scripts/
│   ├── install.sh          # Install release to /Applications
│   └── update_readme_version.sh
└── Modules/
    ├── App
    ├── Capture
    ├── Overlay
    ├── Settings
    ├── AI
    ├── Update
    └── Utils
```

### Modules

- App: app entry and menu bar setup
- Capture: lightshot-style screen capture pipeline
- Overlay: lightshot-style selection UI, tools, and AI prompt
- Settings: hotkey and AI preferences
- AI: OpenAI image edit client
- Update: GitHub release checker (notifications)
- Utils: app paths, version utilities, defaults

## Architecture

1. **AiShot**: Sets up the menu bar icon and handles app lifecycle (lightshot-style)
2. **ScreenshotManager**: Manages lightshot-style screen capture using ScreenCaptureKit
3. **OverlayWindow**: Displays a full-screen lightshot overlay with:
   - Fixed background image (captured screen)
   - Region selection (drag to select)
   - Region editing (move, resize, re-select)
   - Drawing tools (pen, line, arrow, rectangle, circle)
   - Toolbar with tools and action buttons
   - AI prompt for editing the selected region
   - All editing happens in overlay mode without switching windows
4. **UpdateManager** (optional): Checks GitHub releases and posts notifications

## Key Technologies

- **ScreenCaptureKit**: macOS framework for lightshot-style screen capture
- **AppKit**: Native macOS UI framework
- **CGContext**: Core Graphics for drawing and image manipulation
- **UserNotifications**: Update notifications

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

- Lightshot-style tools require clicking a tool button first
- Tools only work inside the captured image area
- Click the tool button again to deselect

### Can't Save Images

- Check file system permissions
- Make sure you have write access to the selected directory

### Update Notifications Not Appearing

- Make sure notifications are enabled for AiShot in System Settings > Notifications
- The update checker polls hourly by default

## Future Enhancements

- More lightshot-like shortcuts and workflows for power users.
- Better AI mask controls to refine edit regions with less manual cleanup.
- More AI models and presets to match different creative styles and use cases.
- Privacy tools (blur/pixelate) to quickly redact sensitive content.
- Manual editing tools to complement AI edits with precise touchups.
- Share to cloud to generate links and sync across devices.
- Capture history to browse, reuse, and manage past screenshots.
- Premium plan with extra AI credits and cloud history for power users.

## License

This is a demonstration project. Feel free to modify and use as needed.

## Notes

- AiShot offers a lightshot-like experience for macOS users
- The app uses `UserNotifications` for quick feedback notifications
- Screen capture requires ScreenCaptureKit
- The app sets itself as `.accessory` to hide from the dock
- Window levels are set to `.screenSaver` and `.floating` for proper overlay behavior
