import SwiftUI

// MARK: - SleepTimerControl

struct SleepTimerControl: View {
    private static let brandAccent = PackageResourceLookup.brandAccent

    let accessibilityID: String

    @Environment(SleepTimerService.self) private var sleepTimer
    @State private var isShowingTimerPopover = false
    @State private var isShowingCustomDurationSheet = false

    var body: some View {
        PlayerBarIconButton(
            action: {
                self.isShowingTimerPopover.toggle()
            },
            isSelected: self.sleepTimer.isActive,
            accessibilityID: self.accessibilityID,
            accessibilityLabel: String(localized: "Sleep Timer"),
            accessibilityValue: self.accessibilityValue
        ) {
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .regular))
                .frame(width: 16, height: 16)
                .foregroundStyle(self.sleepTimer.isActive ? Self.brandAccent : .primary)
        }
        .popover(isPresented: self.$isShowingTimerPopover, arrowEdge: .bottom) {
            self.timerPopover
        }
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
        self.isShowingTimerPopover = false
    }

    private var timerPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sleep Timer")
                .font(.headline)
                .padding(.bottom, 4)

            self.timerAction(String(localized: "15 Minutes"), minutes: 15)
            self.timerAction(String(localized: "30 Minutes"), minutes: 30)
            self.timerAction(String(localized: "45 Minutes"), minutes: 45)
            self.timerAction(String(localized: "1 Hour"), minutes: 60)

            Button(String(localized: "Custom…")) {
                self.isShowingTimerPopover = false
                self.isShowingCustomDurationSheet = true
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            if self.sleepTimer.isActive {
                Divider()
                    .padding(.vertical, 4)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(self.remainingText(at: context.date))
                        .foregroundStyle(.secondary)
                }
                Button(String(localized: "Turn Off Timer")) {
                    self.sleepTimer.cancel()
                    self.isShowingTimerPopover = false
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
    }

    private func timerAction(_ title: String, minutes: Int) -> some View {
        Button(title) {
            self.start(minutes: minutes)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
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

            Text("Enter a whole number of minutes from 1 to 720.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("Minutes", text: self.$minutesText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                    .accessibilityLabel(Text("Minutes"))

                Text("minutes")
                    .foregroundStyle(.secondary)
            }

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
