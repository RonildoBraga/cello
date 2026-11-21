import AVFoundation
import CelloPitch
import SwiftUI

/// Takes are recorded without automatic gain so their pitch reads true, which leaves them
/// too quiet to hear through the speaker. Playback hears a copy brought up to a comfortable
/// level; the saved take, which scoring and sharing use, is never changed.
struct TakeSound {
    /// The loudest moment of the copy, about -6 dBFS.
    static let peak: Float = 0.5
    /// Room hiss stays hiss: a near-silent take is not raised more than this (+34 dB).
    static let maximumGain: Float = 50
    static let barCount = 80

    /// What to play: the louder copy, or the take itself when it is already loud enough.
    let url: URL
    /// The take's shape, one bar per stretch of time, from 0 (silence) to 1 (its loudest).
    let levels: [Float]

    /// Nil when the take cannot be read.
    static func load(recording: URL, duration: Double, id: UUID) async -> TakeSound? {
        guard let samples = try? await RecordingAudio.read(url: recording, maximumDuration: duration + 1),
              let loudest = samples.lazy.map(abs).max(), loudest > 0 else { return nil }
        let levels = shape(of: samples, loudest: loudest)
        let gain = min(peak / loudest, maximumGain)
        guard gain > 1.5 else { return TakeSound(url: recording, levels: levels) }
        let pcm = samples.map { Int16(max(-1, min(1, $0 * gain)) * Float(Int16.max)) }
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("take-\(id.uuidString)").appendingPathExtension("wav")
        guard (try? RecordedReference.wave(pcm).write(to: copy, options: .atomic)) != nil else { return nil }
        return TakeSound(url: copy, levels: levels)
    }

    /// The level of each stretch, on a square-root scale so quiet notes still show.
    private static func shape(of samples: [Float], loudest: Float) -> [Float] {
        let size = max(1, samples.count / barCount)
        return stride(from: 0, to: samples.count, by: size).prefix(barCount).map { start in
            let level = Float(Measure.level(of: samples[start..<min(start + size, samples.count)])) * Float(2).squareRoot()
            return min(1, max(0.04, (level / loudest).squareRoot()))
        }
    }
}

/// A sound-only take: its shape, filling in as it plays, and one button to play or pause.
/// Tapping the shape moves to that moment.
struct TakePlayerView: View {
    let player: AVPlayer
    let sound: TakeSound?
    let duration: Double
    @State private var position: Double = 0
    @State private var playing = false
    @State private var observer: Any?

    var body: some View {
        HStack(spacing: 14) {
            Button(action: toggle) {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.title2).foregroundStyle(.white)
                    .frame(width: 52, height: 52).background(Palette.forest, in: Circle())
            }
            .disabled(sound == nil)
            .accessibilityLabel(playing ? "Pause" : "Play")
            .accessibilityIdentifier("takePlayButton")
            VStack(alignment: .leading, spacing: 6) {
                waveform.frame(height: 44)
                Text("\(timeString(position)) / \(timeString(duration))")
                    .font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
            }
        }
        .padding(14)
        .background(Palette.forest.opacity(0.06), in: RoundedRectangle(cornerRadius: Layout.cardRadius))
        .onAppear(perform: observe)
        .onDisappear(perform: stopObserving)
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { note in
            guard (note.object as? AVPlayerItem) === player.currentItem else { return }
            playing = false
            position = 0
            player.seek(to: .zero)
        }
    }

    private var waveform: some View {
        GeometryReader { geometry in
            let levels = sound?.levels ?? Array(repeating: 0.04, count: TakeSound.barCount)
            let played = duration > 0 ? position / duration : 0
            HStack(alignment: .center, spacing: 2) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule()
                        .fill(Double(index) / Double(levels.count) < played ? Palette.forest : Palette.muted.opacity(0.35))
                        .frame(height: max(3, geometry.size.height * CGFloat(levels[index])))
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { location in
                seek(to: duration * min(max(location.x / geometry.size.width, 0), 1))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Sound of the take")
        .accessibilityValue("\(timeString(position)) of \(timeString(duration))")
    }

    private func toggle() {
        if playing { player.pause() } else { player.play() }
        playing.toggle()
    }

    private func seek(to seconds: Double) {
        position = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func observe() {
        guard observer == nil else { return }
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 20), queue: .main) { time in
            if time.seconds.isFinite { position = min(time.seconds, duration) }
        }
    }

    private func stopObserving() {
        player.pause()
        playing = false
        if let observer { player.removeTimeObserver(observer) }
        observer = nil
    }
}
