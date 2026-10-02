import DeviceActivity
import ManagedSettings

/// Runs at 4 AM each day: if today's Rootwork isn't done, rest the chosen apps again.
final class GateMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if !GateShared.completedToday { GateShared.rest() }
    }
}
