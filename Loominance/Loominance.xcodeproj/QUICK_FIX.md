# Quick Fix Reference Card 🚀

## The #1 Thing to Do Right Now

```bash
# Open Terminal and run:
tccutil reset ScreenCapture

# Then in Xcode:
# 1. Product → Clean Build Folder (⇧⌘K)
# 2. Run the app
# 3. Click "Grant Permission" when prompted
```

---

## Permission Not Working? Try These in Order:

### 1️⃣ Quick Reset
```bash
tccutil reset ScreenCapture
```
Then rebuild in Xcode.

### 2️⃣ Manual Settings
System Settings → Privacy & Security → Screen Recording
- Find your app
- Toggle OFF then ON
- Quit and restart app

### 3️⃣ Clean Everything
```bash
# Delete app
rm -rf /Applications/Loominance.app

# Reset permissions
tccutil reset ScreenCapture

# In Xcode: Clean Build Folder (⇧⌘K)
```

### 4️⃣ Nuclear Option
```bash
# Full reset
tccutil reset All

# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Restart Mac
sudo reboot
```

---

## Common Errors & Quick Fixes

| Error | Quick Fix |
|-------|-----------|
| "Permission denied" | `tccutil reset ScreenCapture` |
| "User declined" | Open System Settings manually |
| No popup shows | Reset TCC, then clean build |
| "Unable to obtain task name port" | This is normal before permission granted |
| Works in Xcode, not standalone | Code signing issue - check certificate |

---

## Useful Commands

```bash
# Reset your app's permission
tccutil reset ScreenCapture com.yourcompany.loominance

# Reset all screen recording permissions
tccutil reset ScreenCapture

# Check current permissions
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access WHERE service='kTCCServiceScreenCapture';"

# Clear Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData
```

---

## Testing Checklist

- [ ] Clean build in Xcode
- [ ] Run app
- [ ] Permission dialog appears
- [ ] Click "Allow"
- [ ] Permission granted ✅
- [ ] Can capture screen ✅
- [ ] Permission persists after restart ✅

---

## Debug View

Add to your app for testing:
```swift
import SwiftUI

struct YourSettingsView: View {
    var body: some View {
        Button("Show Permission Debug") {
            let window = NSWindow(
                contentViewController: NSHostingController(rootView: PermissionDebugView())
            )
            window.makeKeyAndOrderFront(nil)
        }
    }
}
```

---

## Key Files Changed

✅ `PermissionManager.swift` - Updated to use ScreenCaptureKit
✅ `OnboardingView.swift` - Better permission UI
✅ `Info.plist` - Added usage description (NEW)
✅ `PermissionRequestView.swift` - Reusable component (NEW)
✅ `PermissionDebugView.swift` - Debug tool (NEW)

---

## When to Use What

### PermissionManager
```swift
// Check permission
await PermissionManager.shared.checkScreenRecordingPermission()

// Request permission
PermissionManager.shared.requestScreenRecordingPermission()
    .sink { state in
        print("Permission: \(state)")
    }

// Open Settings
PermissionManager.shared.openSystemSettingsScreenRecording()
```

### PermissionRequestView
```swift
// Show permission UI
.sheet(isPresented: $showPermission) {
    PermissionRequestView()
}
```

### PermissionDebugView
```swift
// Show debug panel
.sheet(isPresented: $showDebug) {
    PermissionDebugView()
}
```

---

## Expected Behavior

| State | What Happens |
|-------|-------------|
| First time | Shows permission dialog |
| User allows | ✅ Can record screen |
| User denies | Shows "Open Settings" button |
| After manual enable | App detects on recheck |
| Permission revoked | App shows warning |

---

## Don't Forget

1. **Info.plist must be in target** - Check target membership
2. **Bundle ID matters** - Use correct ID in tccutil commands
3. **Quit completely** - Close app fully after permission changes
4. **Restart helps** - When in doubt, restart Mac
5. **Check Console.app** - For detailed error messages

---

## Still Stuck?

1. Read `SCREEN_RECORDING_TROUBLESHOOTING.md`
2. Use `PermissionDebugView` to diagnose
3. Check `PERMISSION_FIX_SUMMARY.md` for details
4. Look at Console.app logs (filter by app name)

---

## Quick Test

```swift
// Add this to test quickly
Task {
    await PermissionManager.shared.checkScreenRecordingPermission()
    print("Permission: \(PermissionManager.shared.screenRecordingPermission)")
}
```

---

**Remember**: Permission dialog only shows ONCE per reset!
If you miss it, reset with `tccutil reset ScreenCapture`

---

✅ **You're all set!** Just reset TCC, clean build, and try again.
