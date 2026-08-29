import Foundation
import Testing
@testable import Kaset

@Suite("Track boundary advertisement policy")
struct TrackBoundaryAdPolicyTests {
    @Test("Measured end advertisement completes the track")
    func measuredEndAdvertisementCompletesTrack() {
        let input = Self.endInput(progress: 183.772, duration: 183.7935)

        #expect(TrackBoundaryAdPolicy.shouldCompleteTrack(for: input))
    }

    @Test("End advertisement outside the terminal threshold does not complete the track")
    func endAdvertisementOutsideThresholdDoesNotCompleteTrack() {
        let input = Self.endInput(progress: 183.2, duration: 183.7935)

        #expect(!TrackBoundaryAdPolicy.shouldCompleteTrack(for: input))
    }

    @Test(
        "Invalid duration does not complete the track",
        arguments: [
            TimeInterval.zero,
            -1,
            .infinity,
            -.infinity,
            .nan,
        ]
    )
    func invalidDurationDoesNotCompleteTrack(duration: TimeInterval) {
        let input = Self.endInput(progress: 0, duration: duration)

        #expect(!TrackBoundaryAdPolicy.shouldCompleteTrack(for: input))
    }

    @Test("Progress beyond duration does not complete the track")
    func progressBeyondDurationDoesNotCompleteTrack() {
        let input = Self.endInput(progress: 184, duration: 183.7935)

        #expect(!TrackBoundaryAdPolicy.shouldCompleteTrack(for: input))
    }

    @Test(
        "Every end-boundary guard is required",
        arguments: [
            Self.endInput(isEnabled: false),
            Self.endInput(isAdRisingEdge: false),
            Self.endInput(songNearingEnd: false),
            Self.endInput(contentIdentityMatchesRequestedTrack: false),
            Self.endInput(hasCurrentPlaybackIntent: false),
            Self.endInput(hasCurrentPlaybackOccurrence: false),
            Self.endInput(isExplicitPauseIntentActive: true),
        ]
    )
    func everyEndBoundaryGuardIsRequired(input: EndOfTrackAdDecisionInput) {
        #expect(!TrackBoundaryAdPolicy.shouldCompleteTrack(for: input))
    }

    @Test("Measured pre-roll advertisement retries the requested track")
    func measuredPreRollAdvertisementRetriesTrack() {
        #expect(TrackBoundaryAdPolicy.shouldRetryTrack(for: Self.preRollInput()))
    }

    @Test(
        "Every pre-roll guard is required",
        arguments: [
            Self.preRollInput(isEnabled: false),
            Self.preRollInput(isAdRisingEdge: false),
            Self.preRollInput(hasRequestedTrack: false),
            Self.preRollInput(hasCurrentPlaybackIntent: false),
            Self.preRollInput(isCurrentDocument: false),
            Self.preRollInput(hasAuthoritativeContentProgressed: true),
            Self.preRollInput(retryAttempt: TrackBoundaryAdPolicy.maximumPreRollRetryAttempts),
            Self.preRollInput(isExplicitPauseIntentActive: true),
        ]
    )
    func everyPreRollGuardIsRequired(input: PreRollAdDecisionInput) {
        #expect(!TrackBoundaryAdPolicy.shouldRetryTrack(for: input))
    }

    @Test("Pre-roll retry accepts attempts below its fixed limit")
    func preRollRetryAcceptsAttemptsBelowLimit() {
        for attempt in 0 ..< TrackBoundaryAdPolicy.maximumPreRollRetryAttempts {
            #expect(TrackBoundaryAdPolicy.shouldRetryTrack(for: Self.preRollInput(retryAttempt: attempt)))
        }
    }

    @Test("Only positive finite progress marks content as started")
    func onlyPositiveFiniteProgressMarksContentStarted() {
        #expect(!TrackBoundaryAdPolicy.hasAuthoritativeContentProgressed(0))
        #expect(!TrackBoundaryAdPolicy.hasAuthoritativeContentProgressed(-1))
        #expect(!TrackBoundaryAdPolicy.hasAuthoritativeContentProgressed(.nan))
        #expect(!TrackBoundaryAdPolicy.hasAuthoritativeContentProgressed(.infinity))
        #expect(TrackBoundaryAdPolicy.hasAuthoritativeContentProgressed(0.001))
    }

    @Test("End and pre-roll settings remain independent")
    func settingsRemainIndependent() {
        for skipsEndAds in [false, true] {
            for retriesPreRollAds in [false, true] {
                let endInput = Self.endInput(isEnabled: skipsEndAds)
                let preRollInput = Self.preRollInput(isEnabled: retriesPreRollAds)

                #expect(TrackBoundaryAdPolicy.shouldCompleteTrack(for: endInput) == skipsEndAds)
                #expect(TrackBoundaryAdPolicy.shouldRetryTrack(for: preRollInput) == retriesPreRollAds)
            }
        }
    }

    private static func endInput(
        isEnabled: Bool = true,
        isAdRisingEdge: Bool = true,
        songNearingEnd: Bool = true,
        progress: TimeInterval = 179.8,
        duration: TimeInterval = 180,
        contentIdentityMatchesRequestedTrack: Bool = true,
        hasCurrentPlaybackIntent: Bool = true,
        hasCurrentPlaybackOccurrence: Bool = true,
        isExplicitPauseIntentActive: Bool = false
    ) -> EndOfTrackAdDecisionInput {
        EndOfTrackAdDecisionInput(
            isEnabled: isEnabled,
            isAdRisingEdge: isAdRisingEdge,
            songNearingEnd: songNearingEnd,
            contentProgress: progress,
            contentDuration: duration,
            contentIdentityMatchesRequestedTrack: contentIdentityMatchesRequestedTrack,
            hasCurrentPlaybackIntent: hasCurrentPlaybackIntent,
            hasCurrentPlaybackOccurrence: hasCurrentPlaybackOccurrence,
            isExplicitPauseIntentActive: isExplicitPauseIntentActive
        )
    }

    private static func preRollInput(
        isEnabled: Bool = true,
        isAdRisingEdge: Bool = true,
        hasRequestedTrack: Bool = true,
        hasCurrentPlaybackIntent: Bool = true,
        isCurrentDocument: Bool = true,
        hasAuthoritativeContentProgressed: Bool = false,
        retryAttempt: Int = 0,
        isExplicitPauseIntentActive: Bool = false
    ) -> PreRollAdDecisionInput {
        PreRollAdDecisionInput(
            isEnabled: isEnabled,
            isAdRisingEdge: isAdRisingEdge,
            hasRequestedTrack: hasRequestedTrack,
            hasCurrentPlaybackIntent: hasCurrentPlaybackIntent,
            isCurrentDocument: isCurrentDocument,
            hasAuthoritativeContentProgressed: hasAuthoritativeContentProgressed,
            retryAttempt: retryAttempt,
            isExplicitPauseIntentActive: isExplicitPauseIntentActive
        )
    }
}
