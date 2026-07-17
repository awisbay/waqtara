import SwiftUI
import WaqtaraCore

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            LocationSettingsView()
                .tabItem { Label(state.l.tabLocation, systemImage: "location") }
            CalculationSettingsView()
                .tabItem { Label(state.l.tabCalculation, systemImage: "function") }
            ReminderSettingsView()
                .tabItem { Label(state.l.tabReminder, systemImage: "bell") }
            GeneralSettingsView()
                .tabItem { Label(state.l.tabGeneral, systemImage: "gearshape") }
        }
        .frame(width: 460, height: 420)
    }
}

struct LocationSettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(state.l.activeLocation): **\(state.settings.location.name)**")
            TextField(state.l.searchCity, text: $query)
                .textFieldStyle(.roundedBorder)
            List(results) { city in
                HStack {
                    Text(city.name)
                    Text(city.country).foregroundStyle(.secondary).font(.caption)
                    Spacer()
                    if state.settings.location.name == city.name {
                        Image(systemName: "checkmark").foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { state.selectLocation(city.location, country: city.country) }
            }
            Text("\(state.l.coordinates): \(state.settings.location.latitude, specifier: "%.2f"), \(state.settings.location.longitude, specifier: "%.2f") · \(state.settings.location.timeZoneIdentifier)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
    }

    private var results: [City] {
        state.cityDatabase?.search(query) ?? []
    }
}

struct CalculationSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Picker(state.l.method, selection: $state.settings.calculation.method) {
                Text(state.l.methodKemenag).tag(WaqtaraMethod.kemenag)
                Text("Muslim World League").tag(WaqtaraMethod.muslimWorldLeague)
                Text("Univ. of Islamic Sciences Karachi").tag(WaqtaraMethod.karachi)
                Text("ISNA").tag(WaqtaraMethod.northAmerica)
                Text("Umm al-Qura").tag(WaqtaraMethod.ummAlQura)
                Text("Egyptian General Authority").tag(WaqtaraMethod.egyptian)
                Text("Custom").tag(WaqtaraMethod.custom)
            }

            if state.settings.calculation.method == .custom {
                TextField(state.l.fajrAngle, value: $state.settings.calculation.customFajrAngle, format: .number)
                TextField(state.l.ishaAngle, value: $state.settings.calculation.customIshaAngle, format: .number)
            }

            Picker(state.l.asrMadhab, selection: $state.settings.calculation.madhab) {
                Text("Syafi'i").tag(CalculationSettings.AsrMadhab.shafi)
                Text("Hanafi").tag(CalculationSettings.AsrMadhab.hanafi)
            }

            Section(state.l.minuteCorrections) {
                offsetStepper(.shubuh, $state.settings.calculation.adjustments.shubuh)
                offsetStepper(.terbit, $state.settings.calculation.adjustments.terbit)
                offsetStepper(.dzuhur, $state.settings.calculation.adjustments.dzuhur)
                offsetStepper(.ashar, $state.settings.calculation.adjustments.ashar)
                offsetStepper(.maghrib, $state.settings.calculation.adjustments.maghrib)
                offsetStepper(.isya, $state.settings.calculation.adjustments.isya)
            }

            Picker(state.l.rounding, selection: $state.settings.calculation.rounding) {
                Text(state.l.roundingNearest).tag(RoundingMode.nearest)
                Text(state.l.roundingUp).tag(RoundingMode.up)
                Text(state.l.roundingDown).tag(RoundingMode.down)
            }
        }
        .formStyle(.grouped)
    }

    private func offsetStepper(_ prayer: PrayerName, _ value: Binding<Int>) -> some View {
        Stepper("\(state.prayerName(prayer)): \(value.wrappedValue >= 0 ? "+" : "")\(value.wrappedValue) \(state.l.minutes)",
                value: value, in: -15...15)
    }
}

struct ReminderSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Section(state.l.phase1) {
                Toggle(state.l.preAzanToggle, isOn: $state.settings.reminders.preAzanEnabled)
                if state.settings.reminders.preAzanEnabled {
                    Stepper(state.l.minutesBefore(state.settings.reminders.preAzanMinutes),
                            value: $state.settings.reminders.preAzanMinutes, in: 5...30, step: 5)
                    TextField(state.l.customMessagePlaceholder, text: $state.settings.reminders.preAzanMessage,
                              axis: .vertical)
                    Text(state.l.customMessageHint).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section(state.l.phase3) {
                Toggle(state.l.postAzanToggle, isOn: $state.settings.reminders.postAzanEnabled)
                if state.settings.reminders.postAzanEnabled {
                    Stepper(state.l.minutesAfter(state.settings.reminders.postAzanMinutes),
                            value: $state.settings.reminders.postAzanMinutes, in: 10...60, step: 5)
                    TextField(state.l.customMessagePlaceholder, text: $state.settings.reminders.postAzanMessage,
                              axis: .vertical)
                    Text(state.l.customMessageHint).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section(state.l.perPrayerSection) {
                ForEach([PrayerName.shubuh, .dzuhur, .ashar, .maghrib, .isya], id: \.self) { prayer in
                    Toggle(state.prayerName(prayer), isOn: Binding(
                        get: { state.settings.reminders.isEnabled(prayer) },
                        set: { state.settings.reminders.enabledPrayers[prayer.rawValue] = $0 }
                    ))
                }
            }
            Section(state.l.fridaySection) {
                Toggle(state.l.fridayToggle, isOn: $state.settings.reminders.fridayEnabled)
            }
            Section {
                Toggle(state.l.centerAlertToggle, isOn: $state.settings.reminders.centerAlertEnabled)
                Button(state.l.testCenterAlert) {
                    CenterAlert.show(title: state.l.azanTitle(state.prayerName(.dzuhur)),
                                     message: state.l.azanBody(state.prayerName(.dzuhur), state.settings.location.name),
                                     systemImage: "moon.stars.fill", accent: .orange,
                                     dismissTitle: state.l.dismiss)
                }
            }
            Section {
                Button(state.l.testNotification) {
                    state.reminderEngine.sendTestNotification(locationName: state.settings.location.name, l: state.l)
                }
                if !state.reminderEngine.authorized {
                    Text(state.l.notifPermissionWarning)
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Form {
            Picker(state.l.language, selection: $state.settings.language) {
                ForEach(AppLanguage.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Picker(state.l.menuBarDisplay, selection: $state.settings.displayMode) {
                ForEach(MenuBarDisplayMode.allCases, id: \.self) { Text(state.l.displayModeLabel($0)).tag($0) }
            }
            Toggle(state.l.use24h, isOn: $state.settings.use24Hour)
            Toggle(state.l.launchAtLogin, isOn: Binding(
                get: { state.settings.launchAtLogin },
                set: { state.settings.launchAtLogin = $0; LaunchAtLogin.set($0) }
            ))
            Section(state.l.azanSection) {
                Toggle(state.l.azanToggle, isOn: $state.settings.azanEnabled)
                if state.settings.azanEnabled {
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: Binding(
                            get: { state.settings.azanVolume },
                            set: { state.settings.azanVolume = $0; state.azanPlayer.setVolume($0) }
                        ), in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                    Button(state.l.testAzan) {
                        state.azanPlayer.play(for: .dzuhur, volume: state.settings.azanVolume)
                    }
                    if state.azanPlayer.isPlaying {
                        Button(state.l.stopAzan) { state.azanPlayer.stop() }
                    }
                }
            }
            Stepper(state.l.hijriCorrection(state.settings.hijriOffsetDays),
                    value: $state.settings.hijriOffsetDays, in: -2...2)
            Section {
                Text(state.l.about)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
