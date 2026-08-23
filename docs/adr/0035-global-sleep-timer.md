# ADR-0035: Global Runtime Sleep Timer

## Status

Accepted.

## Context

Kaset has two independent playback sources: YouTube Music and regular YouTube.
Users need one countdown that can be configured from either player bar and
pauses whichever source is playing when it expires.

## Decision

`KasetApp` owns one `SleepTimerService` and injects that same instance into the
main window and detached YouTube window. The service retains only an in-memory
deadline and a cancellable task; it does not use `UserDefaults`, Keychain,
files, cloud storage, or networking.

Each valid start replaces the prior countdown. A monotonically increasing
generation prevents a cancelled or stale task from clearing or expiring a
replacement timer. The service uses a monotonic sleep operation for scheduling
and a wall-clock deadline for display and early-wake correction.

At expiry, the service calls `PlaybackArbiter.pauseActivePlayback()`. The
arbiter pauses exactly one source: routed, playing video first; otherwise
playing music; otherwise a playing video as a defensive routing fallback.

## Consequences

The countdown remains active through source switches, playback pauses, and
window changes, but is deliberately discarded when the app quits. This keeps
the feature local and predictable while avoiding a second timer state for each
player.
