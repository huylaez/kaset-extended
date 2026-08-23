# ADR-0034: Playback System Sleep Prevention

## Status

Accepted

## Context

Kaset can play music or regular YouTube video for long periods. macOS may enter
idle system sleep while playback continues unless the app holds a process
activity. The app has separate music and video player services, so allowing
each player to manage a separate activity could briefly release the assertion
during handoff or leave an assertion active after playback stops.

## Decision

Kaset provides a default-off General setting for preventing idle system sleep
while content is playing.

- `KasetApp` owns one `SystemSleepPreventer` for the lifetime of both player
  services.
- The preventer holds one `ProcessInfo` activity only when the setting is
  enabled and either player reports `isPlaying`.
- The activity uses `.idleSystemSleepDisabled`; it intentionally does not use
  `.idleDisplaySleepDisabled`, so the display continues following macOS user
  settings.
- The process activity bridge is injected into the preventer so unit tests use
  a fake and never affect the machine's real power state.
- Only the Boolean preference is stored in `UserDefaults`; the active process
  activity is runtime-only and is released when playback stops or the setting
  is disabled.

## Consequences

The feature is local-only and does not alter macOS power preferences, request
an entitlement, or contact a server. Explicit user-initiated sleep remains
available. A single reconciled activity avoids duplicate assertions and keeps
sleep prevention stable during Music-to-YouTube handoffs.
