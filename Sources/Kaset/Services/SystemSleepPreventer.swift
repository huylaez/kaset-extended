import Foundation

/// Abstracts the process activity APIs so sleep prevention can be tested without
/// changing the power state of the machine running the tests.
@MainActor
protocol SystemSleepActivityControlling: AnyObject {
    func beginIdleSystemSleepPrevention(reason: String) -> NSObjectProtocol
    func endActivity(_ activity: NSObjectProtocol)
}

/// The production bridge to macOS process activities.
@MainActor
final class ProcessInfoSystemSleepActivityController: SystemSleepActivityControlling {
    func beginIdleSystemSleepPrevention(reason: String) -> NSObjectProtocol {
        ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled],
            reason: reason
        )
    }

    func endActivity(_ activity: NSObjectProtocol) {
        ProcessInfo.processInfo.endActivity(activity)
    }
}

/// Holds one macOS activity while enabled playback is active in either player.
@MainActor
final class SystemSleepPreventer {
    private let activityController: any SystemSleepActivityControlling
    private var activity: NSObjectProtocol?

    init(activityController: any SystemSleepActivityControlling = ProcessInfoSystemSleepActivityController()) {
        self.activityController = activityController
    }

    func reconcile(isEnabled: Bool, isMusicPlaying: Bool, isVideoPlaying: Bool) {
        let shouldPreventSleep = isEnabled && (isMusicPlaying || isVideoPlaying)

        if shouldPreventSleep {
            guard self.activity == nil else { return }
            self.activity = self.activityController.beginIdleSystemSleepPrevention(
                reason: "Kaset is playing media"
            )
        } else {
            self.stop()
        }
    }

    func stop() {
        guard let activity = self.activity else { return }
        self.activityController.endActivity(activity)
        self.activity = nil
    }
}
