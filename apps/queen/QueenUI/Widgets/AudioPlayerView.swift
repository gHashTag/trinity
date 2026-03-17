// Audio Player View — Audio Playback Controls
import SwiftUI

// MARK: - Audio Player

struct AudioPlayerView: View {
    let title: String
    let artist: String?
    let duration: TimeInterval
    @Binding var currentTime: TimeInterval
    @Binding var isPlaying: Bool
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 16) {
            // Album art placeholder
            albumArt

            // Track info
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)

                if let artist = artist {
                    Text(artist)
                        .font(.system(size: 13))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }

            // Progress
            VStack(spacing: 6) {
                progressSlider

                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)

                    Spacer()

                    Text(formatTime(duration))
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }

            // Controls
            playbackControls
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }

    private var albumArt: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [TrinityTheme.accent.opacity(0.3), TrinityTheme.accent.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 180)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.3))
            }
    }

    private var progressSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(TrinityTheme.bgCardBorder)
                    .frame(height: 4)

                let progress = isDragging ? currentTime / duration : currentTime / duration
                RoundedRectangle(cornerRadius: 3)
                    .fill(TrinityTheme.accent)
                    .frame(width: geometry.size.width * CGFloat(progress), height: 4)

                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .offset(x: geometry.size.width * CGFloat(progress) - 6)
            }
        }
        .frame(height: 4)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                }
                .onEnded { value in
                    isDragging = false
                }
        )
    }

    private var playbackControls: some View {
        HStack(spacing: 20) {
            controlButton(icon: "backward.fill") {}

            playButton

            controlButton(icon: "forward.fill") {}
        }
    }

    private var playButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isPlaying.toggle()
            }
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(TrinityTheme.accent)
                )
        }
        .buttonStyle(.plain)
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(TrinityTheme.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Mini Player

struct MiniAudioPlayer: View {
    let title: String
    @Binding var isPlaying: Bool
    @Binding var progress: Double

    var body: some View {
        HStack(spacing: 12) {
            // Album art thumbnail
            RoundedRectangle(cornerRadius: 6)
                .fill(TrinityTheme.accent.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 16))
                        .foregroundStyle(TrinityTheme.accent)
                }

            // Info and controls
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .lineLimit(1)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(TrinityTheme.bgCardBorder)
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(TrinityTheme.accent)
                            .frame(width: geometry.size.width * CGFloat(progress), height: 3)
                    }
                }
                .frame(height: 3)
            }

            // Play button
            Button {
                withAnimation {
                    isPlaying.toggle()
                }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(TrinityTheme.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Voice Recording

struct VoiceRecordingView: View {
    let isRecording: Bool
    let duration: TimeInterval
    let onCancel: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Animated waveform
            waveform

            Text(formatTime(duration))
                .font(.system(size: 32, weight: .light, design: .monospaced))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text(isRecording ? "Recording..." : "Paused")
                .font(.caption)
                .foregroundStyle(TrinityTheme.statusError)

            // Controls
            HStack(spacing: 40) {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(TrinityTheme.textMuted)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onStop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(TrinityTheme.statusError)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
    }

    private var waveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<30) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(TrinityTheme.accent)
                    .frame(width: 3, height: CGFloat.random(in: 10...40))
                    .animation(
                        .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.02),
                        value: isRecording
                    )
            }
        }
        .frame(height: 50)
        .onAppear {
            // Start animation
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Waveform

struct AudioWaveform: View {
    let samples: [Float]
    let color: Color
    let isPlaying: Bool

    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width / CGFloat(samples.count)

            HStack(spacing: 1) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    Rectangle()
                        .fill(color)
                        .frame(
                            width: max(1, barWidth - 1),
                            height: CGFloat(abs(sample)) * geometry.size.height * 0.8
                        )
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 40)
    }
}

// MARK: - Volume Control

struct VolumeControl: View {
    @Binding var volume: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: volumeIcon)
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textMuted)
                .frame(width: 16)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(TrinityTheme.bgCardBorder)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(TrinityTheme.accent)
                        .frame(width: geometry.size.width * CGFloat(volume), height: 4)

                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .offset(x: geometry.size.width * CGFloat(volume) - 6)
                }
            }
            .frame(height: 4)

            Text("\(Int(volume * 100))%")
                .font(.caption2)
                .foregroundStyle(TrinityTheme.textMuted)
                .frame(width: 30)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Handle volume change
                }
        )
    }

    private var volumeIcon: String {
        if volume == 0 {
            return "speaker.slash.fill"
        } else if volume < 0.3 {
            return "speaker.fill"
        } else if volume < 0.7 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Playlist Item

struct PlaylistItem: View {
    let title: String
    let duration: TimeInterval
    let isPlaying: Bool
    let onPlay: () -> Void

    var body: some View {
        Button {
            onPlay()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isPlaying ? TrinityTheme.accent : TrinityTheme.textMuted)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(isPlaying ? TrinityTheme.accent : TrinityTheme.textPrimary)
                        .lineLimit(1)

                    Text(formatTime(duration))
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)
                }

                Spacer()

                if isPlaying {
                    AudioWaveform(samples: Array(repeating: 0.5, count: 30), color: TrinityTheme.accent, isPlaying: true)
                        .frame(width: 60)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPlaying ? TrinityTheme.accent.opacity(0.1) : Color.clear)
        )
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

struct AudioPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AudioPlayerView(
                title: "Example Track",
                artist: "Artist Name",
                duration: 245,
                currentTime: .constant(123),
                isPlaying: .constant(true)
            )
            .frame(width: 300)

            MiniAudioPlayer(
                title: "Now Playing",
                isPlaying: .constant(true),
                progress: .constant(0.6)
            )
            .frame(width: 320)

            VolumeControl(volume: .constant(0.7))
                .frame(width: 150)

            PlaylistItem(
                title: "Episode 1: Introduction",
                duration: 1845,
                isPlaying: false
            ) {}
            .frame(width: 300)
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
