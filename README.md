# Token Usage Monitor 🚀

A lightweight, native macOS menu bar utility built with SwiftUI. It provides real-time visibility into your API budget and token spending so you never hit unexpected limits.

---

## 💻 Requirements

* macOS 13.0+
* Xcode 15.0+
* Swift 5.9+

---

## 🚀 Getting Started (Local Development)

1. Clone the repository.
2. Open `TokenUsageMonitor.xcodeproj` in Xcode.
3. Select your local Mac as the run destination.
4. Build and Run (`⌘R`).

---

## 📦 Generating a Release DMG (For Developers)

To distribute the app outside the Mac App Store, package it as an Apple Disk Image (`.dmg`). We use `create-dmg` to script a clean, professional installer window where users can drag the app directly into their Applications folder.

### 1. Install Dependencies
Ensure you have Homebrew installed, then grab the `create-dmg` CLI:
```bash
brew install create-dmg
```

### 2. Archive and Export the App

1. In Xcode, set the run destination to **Any Mac (Apple Silicon, Intel)**.
2. Go to **Product > Archive**.
3. In the Organizer window, select **Distribute App** > **Custom** (or **Direct Distribution**) > **Copy App**.
4. Export the `TokenUsageMonitor.app` bundle to a dedicated build folder (e.g., `~/Desktop/Builds`).

### 3. Build the DMG

Open your terminal, navigate to your build folder, and run the following script. Modify the paths if your `.app` is located elsewhere:

```bash
create-dmg \
  --volname "Token Usage Monitor" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "TokenUsageMonitor.app" 150 190 \
  --hide-extension "TokenUsageMonitor.app" \
  --app-drop-link 450 190 \
  "TokenUsageMonitor.dmg" \
  "TokenUsageMonitor.app"

```

This will generate a `TokenUsageMonitor.dmg` file with a classic drag-to-install interface, ready for distribution!

> **Note:** If distributing to the public, the exported `.app` must be signed with a Developer ID and notarized by Apple before packaging into the DMG to avoid macOS Gatekeeper warnings.
