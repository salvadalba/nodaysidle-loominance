# Screen Recording Permission Troubleshooting Guide

## Quick Fix Checklist

If you're seeing "Permission denied" errors, follow these steps:

### 1. Reset TCC Database
Open Terminal and run:
```bash
# Reset for your specific app (replace bundle ID)
tccutil reset ScreenCapture com.yourcompany.loominance

# Or reset all screen recording permissions
tccutil reset ScreenCapture
```

### 2. Clean Build in Xcode
- Press `⇧⌘K` (Product → Clean Build Folder)
- Quit any running instances of the app
- Rebuild and run

### 3. Verify Info.plist
Make sure your `Info.plist` includes:
```xml
<key>NSScreenCaptureDescription</key>
<string>Loominance needs screen recording permission to capture your screen with cinematic zoom effects.</string>
```

### 4. Check Signing & Capabilities
In Xcode:
- Go to your target's "Signing & Capabilities" tab
- Ensure "Automatically manage signing" is enabled
- Or use a valid provisioning profile

---

## Common Issues & Solutions

### Issue: "User declined" error immediately
**Cause:** Permission was previously denied.

**Solution:** 
1. Open System Settings → Privacy & Security → Screen Recording
2. Find your app in the list
3. Toggle the switch OFF, then ON
4. Quit and restart your app

### Issue: No permission dialog appears
**Cause:** The permission prompt only shows once per app.

**Solution:**
1. Remove your app from System Settings (click the minus button)
2. Reset TCC database (see step 1 above)
3. Restart your Mac
4. Run the app again

### Issue: "Unable to obtain a task name port right"
**Cause:** App is trying to access screen recording without permission.

**Solution:**
This is expected before permission is granted. Follow the normal permission flow.

### Issue: Permission granted but still can't record
**Cause:** App needs to be fully restarted after permission granted.

**Solution:**
1. Quit the app completely (not just close the window)
2. Relaunch from Xcode or Finder
3. Try recording again

---

## For Development

### Running from Xcode
When running from Xcode during development:
- Xcode itself needs screen recording permission
- Your app also needs permission separately
- Grant both if prompted

### Code Signing
For screen recording to work:
- App must be properly code signed
- Either with a development certificate
- Or with "Disable Library Validation" entitlement for unsigned builds

### Testing Permission Flow
To test the permission flow multiple times:
```bash
# Reset permissions for testing
tccutil reset ScreenCapture

# Then rebuild and run
```

---

## macOS System Requirements

- macOS 12.3+ for ScreenCaptureKit
- macOS 10.15+ for basic screen recording
- Screen Recording permission available on macOS 10.15+

---

## Debugging Logs

Check Console.app for logs:
1. Open Console.app
2. Filter by process: "Loominance"
3. Look for logs with subsystem: "com.loominance.app"
4. Category: "App" or "CaptureService"

Useful log messages:
- "Screen recording permission: granted/denied"
- "Requesting screen recording permission..."
- "Permission request completed"

---

## Still Having Issues?

### Nuclear Option: Complete Reset
```bash
# 1. Delete the app
rm -rf /Applications/Loominance.app

# 2. Reset all permissions
tccutil reset All

# 3. Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# 4. Restart Mac

# 5. Rebuild from scratch in Xcode
```

### Check System Integrity
```bash
# Verify TCC database isn't corrupted
sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access WHERE service='kTCCServiceScreenCapture';"
```

---

## Best Practices

1. **Always check permission before recording**
   ```swift
   Task {
       await PermissionManager.shared.checkScreenRecordingPermission()
   }
   ```

2. **Handle denied state gracefully**
   - Show helpful UI
   - Provide "Open System Settings" button
   - Explain why permission is needed

3. **Use ScreenCaptureKit for requesting**
   - More reliable than CGRequestScreenCaptureAccess()
   - Provides better error messages
   - Properly triggers permission dialog

4. **Log everything**
   - Use AppLogger for all permission events
   - Makes debugging much easier
   - Helps users diagnose issues

---

## Additional Resources

- [ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit)
- [TCC Database Info](https://developer.apple.com/documentation/bundleresources/information_property_list/protected_resources)
- [Privacy & Permissions Guide](https://developer.apple.com/documentation/bundleresources/information_property_list/protected_resources/requesting_access_to_protected_resources)
