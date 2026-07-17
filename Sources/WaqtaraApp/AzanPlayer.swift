import Foundation
import AVFoundation
import WaqtaraCore

/// Pemutar azan (PRD F4). Dua audio bawaan: standar + Shubuh.
/// Catatan: system-wide audio ducking tidak tersedia di macOS (hanya iOS/AVAudioSession);
/// sebagai gantinya volume azan independen dari slider Settings.
@MainActor
final class AzanPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?

    /// Azan Shubuh memakai audio khusus; waktu lain memakai azan standar.
    func play(for prayer: PrayerName, volume: Double) {
        stop()
        let resource = prayer == .shubuh ? "azan-shubuh" : "azan-standard"
        guard let url = Self.resourceURL(name: resource, ext: "mp3") else {
            NSLog("AzanPlayer: resource %@ tidak ditemukan", resource)
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            NSLog("AzanPlayer: gagal memuat %@: %@", url.path, error.localizedDescription)
            return
        }
        player?.volume = Float(volume)
        player?.delegate = self
        guard player?.play() == true else {
            NSLog("AzanPlayer: play() mengembalikan false untuk %@", url.path)
            return
        }
        NSLog("AzanPlayer: memutar %@ (volume %.2f)", url.lastPathComponent, volume)
        isPlaying = true
    }

    /// Cari resource di Contents/Resources/Waqtara_WaqtaraApp.bundle (app ter-bundle)
    /// sebelum jatuh ke Bundle.module (yang di build SPM executable hanya andal
    /// di mesin development karena memakai path absolut .build/).
    nonisolated static func resourceURL(name: String, ext: String) -> URL? {
        if let resDir = Bundle.main.resourceURL,
           let bundle = Bundle(url: resDir.appendingPathComponent("Waqtara_WaqtaraApp.bundle")),
           let url = bundle.url(forResource: name, withExtension: ext) {
            return url
        }
        return Bundle.module.url(forResource: name, withExtension: ext)
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func setVolume(_ volume: Double) {
        player?.volume = Float(volume)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.player = nil
        }
    }
}
