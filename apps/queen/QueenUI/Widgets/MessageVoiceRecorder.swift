import SwiftUI
import AVFoundation
import Combine

// MARK: - Message Voice Recorder

struct MessageVoiceRecorder: View {
    let onTranscriptReady: (String) -> Void
    let onAudioReady: (URL) -> Void

    @State private var isRecording: Bool = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var audioLevel: Double = 0
    @State private var transcript: String = ""
    @State private var isTranscribing: Bool = false

    @StateObject private var audioRecorder = AudioRecorderManager()

    var body: some View {
        VStack(spacing: ParietalSpacing.lg) {
            // Audio visualization
            audioVisualization

            // Duration and status
            HStack {
                Text(formattedDuration)
                    .font(WernickeTypography.size24.weight(.medium))
                    .foregroundStyle(V4Color.textPrimary)
                    .frame(width: ParietalSpacing.avatarLarge + ParietalSpacing.lg)

                Spacer()

                if isTranscribing {
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Transcribing...")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                }
            }

            // Transcript preview
            if !transcript.isEmpty {
                transcriptPreview
            }

            // Controls
            controlsBar
        }
        .padding(20)
        .background(V4Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(isRecording ? V4Color.error : V4Color.border, lineWidth: 2)
        )
        .cornerRadius(V1Theme.cornerMedium)
    }

    // MARK: - Audio Visualization

    private var audioVisualization: some View {
        HStack(spacing: 3) {
            ForEach(0..<30, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(visualizationColor(for: index))
                    .frame(width: ParietalSpacing.smallIndicator, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true), value: audioLevel)
            }
        }
        .frame(height: 60)
    }

    private func barHeight(for index: Int) -> CGFloat {
        if isRecording {
            let normalizedIndex = Double(index) / 30.0
            let variation = sin(audioLevel * 10 + Double(index) * 0.5) * 0.5 + 0.5
            return 10 + variation * 40
        }
        return 8
    }

    private func visualizationColor(for index: Int) -> Color {
        let normalizedIndex = Double(index) / 30.0
        if isRecording {
            return V4Color.accent.opacity(0.5 + normalizedIndex * 0.5)
        }
        return V4Color.textSecondary.opacity(V2Depth.stateHover)
    }

    // MARK: - Transcript Preview

    private var transcriptPreview: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text("Transcript")
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)
                .padding(.horizontal, ParietalSpacing.md)

            Text(transcript)
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textPrimary)
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(V4Color.background.opacity(V2Depth.stateDisabled))
        .cornerRadius(V1Theme.cornerSmall)
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            // Cancel button
            if isRecording || !transcript.isEmpty {
                Button {
                    cancelRecording()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size28)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Record/Stop button
            Button {
                toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(isRecording ? V4Color.error : V4Color.accent)
                        .frame(width: ParietalSpacing.avatarLarge, height: ParietalSpacing.avatarLarge)

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(WernickeTypography.size24)
                        .foregroundStyle(.white)
                }
                .scaleEffect(isRecording ? recordingPulse : 1.0)
            }
            .buttonStyle(.plain)

            Spacer()

            // Send button
            if !transcript.isEmpty {
                Button {
                    onTranscriptReady(transcript)
                    reset()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(WernickeTypography.size28)
                        .foregroundStyle(V4Color.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    @State private var recordingPulse: CGFloat = 1.0

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        transcript = ""
        audioRecorder.startRecording()
        audioLevel = 0

        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                recordingDuration += 0.1
                audioLevel = Double.random(in: 0...1)
            }
            .store(in: &cancellables)
    }

    private func stopRecording() {
        isRecording = false
        audioRecorder.stopRecording()
        isTranscribing = true

        // Simulate transcription (would use actual Speech API)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            transcript = "This is a sample transcript from the voice recording."
            isTranscribing = false
        }
    }

    private func cancelRecording() {
        isRecording = false
        audioRecorder.stopRecording()
        reset()
    }

    private func reset() {
        transcript = ""
        recordingDuration = 0
        audioLevel = 0
    }

    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Audio Recorder Manager

@MainActor
class AudioRecorderManager: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    func startRecording() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.record()
            recordingURL = tempURL
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
    }

    func getRecordingURL() -> URL? {
        recordingURL
    }
}

// MARK: - Compact Voice Input Button

struct VoiceInputButton: View {
    let onVoiceInput: (String) -> Void

    @State private var showRecorder = false

    var body: some View {
        Button {
            showRecorder = true
        } label: {
            Image(systemName: "mic.circle.fill")
                .font(WernickeTypography.size28)
                .foregroundStyle(V4Color.accent)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showRecorder) {
            MessageVoiceRecorder(
                onTranscriptReady: { transcript in
                    onVoiceInput(transcript)
                    showRecorder = false
                },
                onAudioReady: { _ in }
            )
            .padding()
        }
    }
}

// MARK: - Preview

struct MessageVoiceRecorder_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            MessageVoiceRecorder(
                onTranscriptReady: { _ in },
                onAudioReady: { _ in }
            )
            .frame(width: ParietalSpacing.xl * 16)

            HStack {
                VoiceInputButton { _ in }
                Text("Voice input available")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .padding()
        .background(V4Color.background)
    }
}
