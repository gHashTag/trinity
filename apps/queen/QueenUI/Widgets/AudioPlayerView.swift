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
        VStack(spacing: ParietalSpacing.lg) {
            // Album art placeholder
            albumArt

            // Track info
            VStack(spacing: ParietalSpacing.xs) {
                Text(title)
                    .font(WernickeTypography.body16Medium)
                    .foregroundStyle(V4Color.textPrimary)

                if let artist = artist {
                    Text(artist)
                        .font(WernickeTypography.size13)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            // Progress
            VStack(spacing: ParietalSpacing.sm - 2) {
                progressSlider

                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)

                    Spacer()

                    Text(formatTime(duration))
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            // Controls
            playbackControls
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }

    private var albumArt: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [V4Color.accent.opacity(V2Depth.stateHover), V4Color.accent.opacity(V1Theme.opacityTextSecondary)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 180)
            .overlay {
                Image(systemName: "music.note")
                    .font(WernickeTypography.display)
                    .foregroundStyle(.white.opacity(V2Depth.stateHover))
            }
    }

    private var progressSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(V4Color.border)
                    .frame(height: ParietalSpacing.xs)

                let progress = isDragging ? currentTime / duration : currentTime / duration
                RoundedRectangle(cornerRadius: 3)
                    .fill(V4Color.accent)
                    .frame(width: geometry.size.width * CGFloat(progress), height: ParietalSpacing.microHeight)

                Circle()
                    .fill(.white)
                    .frame(width: ParietalSpacing.sm, height: ParietalSpacing.sm)
                    .offset(x: geometry.size.width * CGFloat(progress) - 6)
            }
        }
        .frame(height: ParietalSpacing.xs)
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
        HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
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
                .font(WernickeTypography.size20)
                .foregroundStyle(.white)
                .frame(width: ParietalSpacing.largeFrame, height: ParietalSpacing.largeButtonHeight)
                .background(
                    Circle()
                        .fill(V4Color.accent)
                )
        }
        .buttonStyle(.plain)
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(WernickeTypography.size18)
                .foregroundStyle(V4Color.textPrimary)
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
        HStack(spacing: ParietalSpacing.md) {
            // Album art thumbnail
            RoundedRectangle(cornerRadius: 6)
                .fill(V4Color.accent.opacity(V2Depth.stateHover))
                .frame(width: ParietalSpacing.avatarMedium - 4, height: ParietalSpacing.avatarMedium - 4)
                .overlay {
                    Image(systemName: "music.note")
                        .font(WernickeTypography.size16)
                        .foregroundStyle(V4Color.accent)
                }

            // Info and controls
            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text(title)
                    .font(WernickeTypography.captionMedium)
                    .foregroundStyle(V4Color.textPrimary)
                    .lineLimit(1)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(V4Color.border)
                            .frame(height: ParietalSpacing.xxxs)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(V4Color.accent)
                            .frame(width: geometry.size.width * CGFloat(progress), height: 3)
                    }
                }
                .frame(height: ParietalSpacing.xxxs)
            }

            // Play button
            Button {
                withAnimation {
                    isPlaying.toggle()
                }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(.white)
                    .frame(width: ParietalSpacing.avatarSmall, height: ParietalSpacing.avatarSmall)
                    .background(
                        Circle()
                            .fill(V4Color.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(V4Color.border, lineWidth: 1)
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
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            // Animated waveform
            waveform

            Text(formatTime(duration))
                .font(WernickeTypography.size32.weight(.light))
                .foregroundStyle(V4Color.textPrimary)

            Text(isRecording ? "Recording..." : "Paused")
                .font(.caption)
                .foregroundStyle(V4Color.error)

            // Controls
            HStack(spacing: ParietalSpacing.xs) {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.size16)
                        .foregroundStyle(.white)
                        .frame(width: ParietalSpacing.avatarMedium, height: ParietalSpacing.avatarMedium)
                        .background(
                            Circle()
                                .fill(V4Color.textSecondary)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onStop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(WernickeTypography.size18)
                        .foregroundStyle(.white)
                        .frame(width: ParietalSpacing.avatarLarge, height: ParietalSpacing.avatarLarge)
                        .background(
                            Circle()
                                .fill(V4Color.error)
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
                    .fill(V4Color.accent)
                    .frame(width: ParietalSpacing.smallIndicator, height: CGFloat.random(in: 10...40))
                    .animation(
                        .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.02),
                        value: isRecording
                    )
            }
        }
        .frame(height: ParietalSpacing.avatarMedium + 2)
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

            HStack(spacing: ParietalSpacing.xxxxs) {
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
        .frame(height: ParietalSpacing.avatarMedium - 8)
    }
}

// MARK: - Volume Control

struct VolumeControl: View {
    @Binding var volume: Double

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            Image(systemName: volumeIcon)
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textSecondary)
                .frame(width: ParietalSpacing.icon)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(V4Color.border)
                        .frame(height: ParietalSpacing.xs)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(V4Color.accent)
                        .frame(width: geometry.size.width * CGFloat(volume), height: ParietalSpacing.microHeight)

                    Circle()
                        .fill(.white)
                        .frame(width: ParietalSpacing.sm, height: ParietalSpacing.sm)
                        .offset(x: geometry.size.width * CGFloat(volume) - 6)
                }
            }
            .frame(height: ParietalSpacing.xs)

            Text("\(Int(volume * 100))%")
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)
                .frame(width: ParietalSpacing.touchFrame)
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
            HStack(spacing: ParietalSpacing.md) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(isPlaying ? V4Color.accent : V4Color.textSecondary)
                    .frame(width: ParietalSpacing.touchFrame)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(WernickeTypography.size13)
                        .foregroundStyle(isPlaying ? V4Color.accent : V4Color.textPrimary)
                        .lineLimit(1)

                    Text(formatTime(duration))
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }

                Spacer()

                if isPlaying {
                    AudioWaveform(samples: Array(repeating: 0.5, count: 30), color: V4Color.accent, isPlaying: true)
                        .frame(width: ParietalSpacing.avatarMedium + ParietalSpacing.md)
                }
            }
            .padding(.vertical, ParietalSpacing.xs + 2)
            .padding(.horizontal, ParietalSpacing.sm)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPlaying ? V4Color.accent.opacity(V2Depth.bgSubtle) : Color.clear)
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
            .frame(width: ParietalSpacing.xl * 12)

            MiniAudioPlayer(
                title: "Now Playing",
                isPlaying: .constant(true),
                progress: .constant(0.6)
            )
            .frame(width: ParietalSpacing.widePanelWidth)

            VolumeControl(volume: .constant(0.7))
                .frame(width: ParietalSpacing.panelWidth)

            PlaylistItem(
                title: "Episode 1: Introduction",
                duration: 1845,
                isPlaying: false
            ) {}
            .frame(width: ParietalSpacing.xl * 12)
        }
        .padding()
        .background(V4Color.background)
    }
}
