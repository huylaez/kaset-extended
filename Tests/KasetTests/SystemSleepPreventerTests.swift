import Foundation
import Testing
@testable import Kaset

@Suite("System sleep preventer")
@MainActor
struct SystemSleepPreventerTests {
    @Test("Disabled playback does not begin an activity")
    func disabledPlaybackDoesNotBeginActivity() {
        let controller = FakeSystemSleepActivityController()
        let preventer = SystemSleepPreventer(activityController: controller)

        preventer.reconcile(isEnabled: false, isMusicPlaying: true, isVideoPlaying: false)

        #expect(controller.beginCount == 0)
        #expect(controller.endCount == 0)
    }

    @Test("Music playback begins one activity")
    func musicPlaybackBeginsActivity() {
        let controller = FakeSystemSleepActivityController()
        let preventer = SystemSleepPreventer(activityController: controller)

        preventer.reconcile(isEnabled: true, isMusicPlaying: true, isVideoPlaying: false)

        #expect(controller.beginCount == 1)
        #expect(controller.endCount == 0)
    }

    @Test("Video playback begins one activity")
    func videoPlaybackBeginsActivity() {
        let controller = FakeSystemSleepActivityController()
        let preventer = SystemSleepPreventer(activityController: controller)

        preventer.reconcile(isEnabled: true, isMusicPlaying: false, isVideoPlaying: true)

        #expect(controller.beginCount == 1)
        #expect(controller.endCount == 0)
    }

    @Test("Repeated active reconciliation retains one activity")
    func repeatedActiveReconciliationRetainsOneActivity() {
        let controller = FakeSystemSleepActivityController()
        let preventer = SystemSleepPreventer(activityController: controller)

        preventer.reconcile(isEnabled: true, isMusicPlaying: true, isVideoPlaying: true)
        preventer.reconcile(isEnabled: true, isMusicPlaying: true, isVideoPlaying: false)
        preventer.reconcile(isEnabled: true, isMusicPlaying: false, isVideoPlaying: true)

        #expect(controller.beginCount == 1)
        #expect(controller.endCount == 0)
    }

    @Test("Activity remains while either player is playing")
    func activityRemainsWhileEitherPlayerIsPlaying() {
        let controller = FakeSystemSleepActivityController()
        let preventer = SystemSleepPreventer(activityController: controller)

        preventer.reconcile(isEnabled: true, isMusicPlaying: true, isVideoPlaying: true)
        preventer.reconcile(isEnabled: true, isMusicPlaying: false, isVideoPlaying: true)

        #expect(controller.beginCount == 1)
        #expect(controller.endCount == 0)
    }

    @Test("Stopping final playback ends the activity once")
    func stoppingFinalPlaybackEndsActivityOnce() {
        let controller = FakeSystemSleepActivityController()
        let preventer = SystemSleepPreventer(activityController: controller)

        preventer.reconcile(isEnabled: true, isMusicPlaying: true, isVideoPlaying: false)
        preventer.reconcile(isEnabled: true, isMusicPlaying: false, isVideoPlaying: false)
        preventer.reconcile(isEnabled: true, isMusicPlaying: false, isVideoPlaying: false)

        #expect(controller.beginCount == 1)
        #expect(controller.endCount == 1)
    }

    @Test("Disabling the setting releases an active activity")
    func disablingSettingReleasesActivity() {
        let controller = FakeSystemSleepActivityController()
        let preventer = SystemSleepPreventer(activityController: controller)

        preventer.reconcile(isEnabled: true, isMusicPlaying: true, isVideoPlaying: false)
        preventer.reconcile(isEnabled: false, isMusicPlaying: true, isVideoPlaying: false)
        preventer.reconcile(isEnabled: true, isMusicPlaying: true, isVideoPlaying: false)

        #expect(controller.beginCount == 2)
        #expect(controller.endCount == 1)
    }

    @Test("Stop is idempotent")
    func stopIsIdempotent() {
        let controller = FakeSystemSleepActivityController()
        let preventer = SystemSleepPreventer(activityController: controller)

        preventer.stop()
        preventer.reconcile(isEnabled: true, isMusicPlaying: true, isVideoPlaying: false)
        preventer.stop()
        preventer.stop()

        #expect(controller.beginCount == 1)
        #expect(controller.endCount == 1)
    }
}

@MainActor
private final class FakeSystemSleepActivityController: SystemSleepActivityControlling {
    private(set) var beginCount = 0
    private(set) var endCount = 0

    func beginIdleSystemSleepPrevention(reason: String) -> NSObjectProtocol {
        self.beginCount += 1
        return NSObject()
    }

    func endActivity(_ activity: NSObjectProtocol) {
        self.endCount += 1
    }
}
