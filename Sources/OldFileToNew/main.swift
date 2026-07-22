import AppKit

// Top-level executable code runs on the main thread; assert that to the compiler so we
// can touch the main-actor-isolated AppKit and AppDelegate APIs directly.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    // Keep a strong reference for the lifetime of the process.
    objc_setAssociatedObject(app, "oldfiletonew.delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    app.run()
}
