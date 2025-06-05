# TODO Widget Sync Issues & Fixes

## Issues Identified

### 1. Widget Bundle Configuration
- **Problem**: Widget bundle only includes `TestWidget()` 
- **Impact**: Potential widget loading issues

### 2. Async Data Loading Race Conditions
- **Problem**: Widget might access data before TodoDataManager is fully initialized
- **Impact**: Empty or stale data in widget

### 3. Storage Strategy Inconsistency  
- **Problem**: App and widget might use different storage methods
- **Impact**: Data not syncing between app and widget

### 4. Widget Timeline Update Timing
- **Problem**: Widget reload called during async operations
- **Impact**: Widget updates with stale data

## Recommended Fixes

### Fix 1: Ensure App Group Storage Works
```swift
// Add to TodoDataManager.swift
func ensureAppGroupAccess() -> Bool {
    guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
        logger.error("❌ App Group container not accessible")
        return false
    }
    
    // Test write access
    let testFile = containerURL.appendingPathComponent("test_write.txt")
    do {
        try "test".write(to: testFile, atomically: true, encoding: .utf8)
        try fileManager.removeItem(at: testFile)
        return true
    } catch {
        logger.error("❌ App Group write test failed: \(error)")
        return false
    }
}
```

### Fix 2: Synchronize Widget Data Access
```swift
// Modify WidgetDataManager
class WidgetDataManager {
    static let shared = WidgetDataManager()
    private init() {}
    
    func getTodos(limit: Int = 10) async -> [TodoItem] {
        // Ensure data manager is ready
        await TodoDataManager.shared.waitForInitialization()
        return await MainActor.run {
            TodoDataManager.shared.fetchIncompleteTodos(limit: limit)
        }
    }
}
```

### Fix 3: Add Initialization Wait Method
```swift
// Add to TodoDataManager
private var _isInitialized = false
private let initializationSemaphore = DispatchSemaphore(value: 0)

func waitForInitialization() async {
    if _isInitialized { return }
    
    await withUnsafeContinuation { continuation in
        DispatchQueue.global().async {
            self.initializationSemaphore.wait()
            continuation.resume()
        }
    }
}

private func markAsInitialized() {
    _isInitialized = true
    initializationSemaphore.signal()
}
```

### Fix 4: Force App Group Storage for Widget Sync
```swift
// Modify setupStorageStrategy in TodoDataManager
private func setupStorageStrategy() async {
    // For widget compatibility, prioritize App Group
    if await tryAppGroupStorage() {
        storageStrategy = .appGroup
        syncStatus = .ready
        logger.info("✅ Using App Group storage")
        return
    }
    
    // Log warning if App Group fails
    logger.warning("⚠️ App Group storage failed - widget sync will be limited")
    
    // Continue with fallback...
}
```

### Fix 5: Improve Widget Timeline Management
```swift
// Modify saveTodos methods to ensure proper timing
private func saveTodosToFile() async {
    // ... existing save logic ...
    
    // Ensure widget reload happens after save is complete
    WidgetCenter.shared.reloadAllTimelines()
    
    // Add small delay to ensure widget has time to read new data
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
}
```

## Testing Steps

1. **Check App Group Access**:
   - Run app and check logs for "App Group storage verified"
   - Verify both app and widget can read/write to shared container

2. **Verify Widget Data Updates**:
   - Add a todo in the main app
   - Check if widget updates within 15 minutes (or force refresh)
   - Toggle completion status and verify widget reflects changes

3. **Test Storage Strategy**:
   - Check TodoDataManager diagnostics to confirm storage strategy
   - Ensure both app and widget use same strategy

4. **Widget Timeline Debugging**:
   - Add logging to widget's getTimeline method
   - Verify widget receives updated data after app changes

## Monitoring Commands

```bash
# Check shared container contents
ls -la ~/Library/Group\ Containers/group.msdtech.todo-macos-widget/

# View app logs
log show --predicate 'subsystem == "msdtech.todo-macos-widget"' --info --last 1h

# Force widget reload (for testing)
# Use Widget configuration in Xcode or iOS Simulator
```
