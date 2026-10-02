import Foundation
import Observation
import FamilyControls
import DeviceActivity

/// The Gate: chosen apps rest each morning until Rootwork is done.
/// Requires the Family Controls entitlement (request distribution access from Apple before TestFlight).
@MainActor @Observable final class GateService {
    var isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    var selection = GateShared.selection {
        didSet { GateShared.selection = selection }
    }
    var restingCount: Int { selection.applicationTokens.count + selection.categoryTokens.count }
    var isOpen: Bool { GateShared.completedToday }

    static let weeklyEmergencyUnlocks = 3

    func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
            startDailySchedule()
        } catch {
            isAuthorized = false
        }
    }

    /// Re-rests apps every day at 4 AM. GateMonitor.intervalDidStart applies the shield.
    func startDailySchedule() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 4, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true)
        try? DeviceActivityCenter().startMonitoring(.init("rootwork.daily"), during: schedule)
        if !GateShared.completedToday { GateShared.rest() }
    }

    func rootworkCompleted() {
        GateShared.lastCompletedDay = Calendar.current.startOfDay(for: .now)
        GateShared.open()
    }

    var emergencyUnlocksLeft: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return Self.weeklyEmergencyUnlocks - GateShared.emergencyUnlocks.filter { $0 > weekAgo }.count
    }

    func emergencyUnlock() {
        guard emergencyUnlocksLeft > 0 else { return }
        GateShared.emergencyUnlocks.append(.now)
        GateShared.open()
    }
}
