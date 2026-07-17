import SwiftUI
import WaqtaraCore

struct PanelView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.gregorianDateString).font(.headline)
                Text("\(state.hijriDateString) H")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Divider()

            if let schedule = state.schedule {
                ForEach(PrayerName.allCases, id: \.self) { prayer in
                    row(prayer: prayer, time: schedule.time(for: prayer))
                }
            } else {
                Text(state.l.scheduleUnavailable)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Image(systemName: "location.fill").font(.caption)
                Text(state.settings.location.name).font(.caption)
                Spacer()
            }
            .foregroundStyle(.secondary)

            if state.azanPlayer.isPlaying {
                HStack {
                    Button {
                        state.azanPlayer.stop()
                    } label: { Label(state.l.stopAzan, systemImage: "speaker.slash.fill") }
                        .tint(.red)
                    Slider(value: Binding(
                        get: { state.settings.azanVolume },
                        set: { state.settings.azanVolume = $0; state.azanPlayer.setVolume($0) }
                    ), in: 0...1)
                }
            }

            HStack {
                if #available(macOS 14.0, *) {
                    OpenSettingsButton(title: state.l.settings)
                } else {
                    Button(state.l.settings) {
                        // Fallback macOS 13.
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
                Spacer()
                Button(state.l.quit) { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 260)
    }

    @ViewBuilder
    private func row(prayer: PrayerName, time: Date) -> some View {
        let isCurrent = state.currentPrayer == prayer
        let isNext = state.nextPrayer?.name == prayer && state.nextPrayer.map { Calendar.current.isDate($0.time, inSameDayAs: state.now) } == true
        HStack {
            Text(state.prayerName(prayer))
                .fontWeight(isCurrent ? .bold : .regular)
                .foregroundStyle(prayer == .terbit ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            Spacer()
            if isNext, let next = state.nextPrayer {
                let remaining = max(0, Int(next.time.timeIntervalSince(state.now)))
                Text(String(format: "−%02d:%02d", remaining / 3600, (remaining % 3600) / 60))
                    .font(.caption).foregroundStyle(.orange)
            }
            Text(state.timeString(time))
                .monospacedDigit()
                .fontWeight(isCurrent ? .bold : .regular)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 6)
        .background(isCurrent ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 5))
    }
}

@available(macOS 14.0, *)
private struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings
    let title: String

    var body: some View {
        Button(title) {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
    }
}
