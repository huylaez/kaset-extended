import SwiftUI

// MARK: - SleepTimerControl

struct SleepTimerControl: View {
    private static let brandAccent = PackageResourceLookup.brandAccent

    let accessibilityID: String

    @Environment(SleepTimerService.self) private var sleepTimer
    @State private var isShowingCustomDurationSheet = false

    var body: some View {
        PlayerBarIconMenu(
            isSelected: self.sleepTimer.isActive,
            accessibilityID: self.accessibilityID,
            accessibilityLabel: String(localized: "Sleep Timer")
        ) {
            Text("Sleep Timer")

            Button(String(localized: "15 Minutes")) {
                self.start(minutes: 15)
            }
            Button(String(localized: "30 Minutes")) {
                self.start(minutes: 30)
            }
            Button(String(localized: "45 Minutes")) {
                self.start(minutes: 45)
            }
            Button(String(localized: "1 Hour")) {
                self.start(minutes: 60)
            }
            Button(String(localized: "Custom…")) {
                self.isShowingCustomDurationSheet = true
            }

            if self.sleepTimer.isActive {
                Divider()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(self.remainingText(at: context.date))
                }
                Button(String(localized: "Turn Off Timer")) {
                    self.sleepTimer.cancel()
                }
            }
        } icon: {
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .regular))
                .frame(width: 16, height: 16)
                .foregroundStyle(self.sleepTimer.isActive ? Self.brandAccent : .primary)
        }
        .accessibilityValue(self.accessibilityValue)
        .sheet(isPresented: self.$isShowingCustomDurationSheet) {
            SleepTimerCustomDurationSheet { minutes in
                guard self.sleepTimer.start(minutes: minutes) else { return }
                self.isShowingCustomDurationSheet = false
            }
        }
    }

    private var accessibilityValue: String {
        guard self.sleepTimer.deadline != nil else { return String(localized: "Off") }
        return self.remainingText(at: .now)
    }

    private func start(minutes: Int) {
        _ = self.sleepTimer.start(minutes: minutes)
    }

    private func remainingText(at date: Date) -> String {
        guard let deadline = self.sleepTimer.deadline else { return String(localized: "Off") }
        let remainingMinutes = max(0, Int(ceil(deadline.timeIntervalSince(date) / 60)))
        let status = String(localized: "Stops in \(remainingMinutes) min")
        return status
    }
}

private struct SleepTimerCustomDurationSheet: View {
    let onStart: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutesText = "60"

    private var minutes: Int? {
        guard let minutes = Int(self.minutesText),
              String(minutes) == self.minutesText,
              SleepTimerService.supportedMinutes.contains(minutes)
        else {
            return nil
        }
        return minutes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Sleep Timer")
                .font(.headline)

            TextField("Minutes", text: self.$minutesText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 130)
                .accessibilityLabel(Text("Minutes"))

            HStack {
                Spacer()
                Button(String(localized: "Cancel")) {
                    self.dismiss()
                }
                Button(String(localized: "Start Timer")) {
                    guard let minutes = self.minutes else { return }
                    self.onStart(minutes)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(self.minutes == nil)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
