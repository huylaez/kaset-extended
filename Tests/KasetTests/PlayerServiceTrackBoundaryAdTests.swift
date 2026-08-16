import Foundation
import Testing
@testable import Kaset

@Suite("PlayerService track boundary advertisements", .serialized, .tags(.service))
@MainActor
struct PlayerServiceTrackBoundaryAdTests {
    @Test("End advertisement retains the content occurrence for terminal handling")
    func endAdvertisementRetainsContentOccurrence() throws {
        let service = Self.makeService(skipsEndAds: true)
        let occurrence = try #require(service.currentMusicPlaybackOccurrence)

        let transition = service.prepareTrackBoundaryAdTransition(
            isAdRisingEdge: true,
            isCurrentDocument: true,
            contentOccurrence: occurrence,
            intent: service.currentMusicPlaybackIntent
        )

        guard case let .completeTrack(videoID, retainedOccurrence, intent) = transition else {
            Issue.record("Expected an end-of-track transition")
            return
        }
        #expect(videoID == "video-a")
        #expect(retainedOccurrence == occurrence)
        #expect(intent == service.currentMusicPlaybackIntent)
        #expect(service.claimTerminalMusicPlaybackOccurrence(retainedOccurrence))
        #expect(!service.claimTerminalMusicPlaybackOccurrence(retainedOccurrence))
    }

    @Test("End advertisement rejects an occurrence owned by another track")
    func endAdvertisementRejectsOccurrenceOwnedByAnotherTrack() {
        let service = Self.makeService(skipsEndAds: true)
        let staleOccurrence = MusicPlaybackOccurrence.web(
            documentGeneration: 1,
            mediaGeneration: 1,
            videoId: "video-b"
        )

        let transition = service.prepareTrackBoundaryAdTransition(
            isAdRisingEdge: true,
            isCurrentDocument: true,
            contentOccurrence: staleOccurrence,
            intent: service.currentMusicPlaybackIntent
        )

        #expect(transition == nil)
    }

    @Test("Pre-roll retry budget survives replacement media occurrences")
    func preRollRetryBudgetSurvivesReplacementOccurrences() {
        let service = Self.makeService(retriesPreRollAds: true, contentProgress: nil)
        let intent = service.currentMusicPlaybackIntent

        let first = service.prepareTrackBoundaryAdTransition(
            isAdRisingEdge: true,
            isCurrentDocument: true,
            contentOccurrence: service.currentMusicPlaybackOccurrence,
            intent: intent
        )
        service.preserveTrackBoundaryAdPlaybackSelection(videoID: "video-a", queueEntryID: service.currentQueueEntryID)
        _ = service.beginNativeMusicPlaybackOccurrence(videoId: "video-a")
        let second = service.prepareTrackBoundaryAdTransition(
            isAdRisingEdge: true,
            isCurrentDocument: true,
            contentOccurrence: service.currentMusicPlaybackOccurrence,
            intent: intent
        )

        guard case .retryTrack = first else {
            Issue.record("Expected the first pre-roll advertisement to retry")
            return
        }
        #expect(second == nil)
    }

    @Test("Accepted content prevents a later ad from becoming pre-roll")
    func acceptedContentPreventsLaterPreRollRetry() {
        let service = Self.makeService(retriesPreRollAds: true, contentProgress: nil)
        service.recordAuthoritativeContentProgressForBoundaryAds(
            0.001,
            observedVideoID: "video-a"
        )

        let transition = service.prepareTrackBoundaryAdTransition(
            isAdRisingEdge: true,
            isCurrentDocument: true,
            contentOccurrence: service.currentMusicPlaybackOccurrence,
            intent: service.currentMusicPlaybackIntent
        )

        #expect(transition == nil)
    }

    @Test("Manual intent change does not turn a seek to zero into pre-roll")
    func manualIntentChangeDoesNotResetContentProgress() {
        let service = Self.makeService(retriesPreRollAds: true, contentProgress: nil)
        service.recordAuthoritativeContentProgressForBoundaryAds(30, observedVideoID: "video-a")
        let seekIntent = service.beginMusicPlaybackIntent()

        let transition = service.prepareTrackBoundaryAdTransition(
            isAdRisingEdge: true,
            isCurrentDocument: true,
            contentOccurrence: service.currentMusicPlaybackOccurrence,
            intent: seekIntent
        )

        #expect(transition == nil)
    }

    @Test("A new playback selection restores the pre-roll retry budget")
    func newPlaybackSelectionRestoresRetryBudget() {
        let service = Self.makeService(retriesPreRollAds: true, contentProgress: nil)
        let intent = service.currentMusicPlaybackIntent
        _ = service.prepareTrackBoundaryAdTransition(
            isAdRisingEdge: true,
            isCurrentDocument: true,
            contentOccurrence: service.currentMusicPlaybackOccurrence,
            intent: intent
        )

        service.beginTrackBoundaryAdPlaybackSelection(
            videoID: "video-a",
            queueEntryID: service.currentQueueEntryID
        )
        let transition = service.prepareTrackBoundaryAdTransition(
            isAdRisingEdge: true,
            isCurrentDocument: true,
            contentOccurrence: service.currentMusicPlaybackOccurrence,
            intent: intent
        )

        guard case .retryTrack = transition else {
            Issue.record("Expected a new selection to receive a fresh retry budget")
            return
        }
    }

    private static func makeService(
        skipsEndAds: Bool = false,
        retriesPreRollAds: Bool = false,
        contentProgress: TimeInterval? = 179.98
    ) -> PlayerService {
        let service = PlayerService()
        let song = Song(
            id: "song-a",
            title: "Song A",
            artists: [],
            album: nil,
            duration: 180,
            thumbnailURL: nil,
            videoId: "video-a"
        )
        let entryID = UUID()
        service.setQueue([song], entryIDs: [entryID])
        service.currentTrack = song
        service.pendingPlayVideoId = song.videoId
        service.activePlaybackQueueEntryID = entryID
        service.beginTrackBoundaryAdPlaybackSelection(videoID: song.videoId, queueEntryID: entryID)
        _ = service.beginNativeMusicPlaybackOccurrence(videoId: song.videoId)
        service.trackBoundaryAdSettingsProvider = {
            TrackBoundaryAdSettings(
                skipsEndOfTrackAds: skipsEndAds,
                retriesPreRollAds: retriesPreRollAds
            )
        }
        if let contentProgress {
            service.recordDurationObservation(videoId: song.videoId, duration: 180)
            service.updateAdPlaybackState(
                isShowingAd: false,
                observedProgress: contentProgress,
                observedVideoId: song.videoId,
                isAuthoritativeContent: true
            )
            service.recordAuthoritativeContentProgressForBoundaryAds(
                contentProgress,
                observedVideoID: song.videoId
            )
            service.songNearingEnd = true
        }
        return service
    }
}
