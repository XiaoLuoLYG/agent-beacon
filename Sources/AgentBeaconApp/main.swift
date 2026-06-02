import AppKit

let app = NSApplication.shared
let delegate = AgentBeaconAppDelegate.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
delegate.start()
app.run()
