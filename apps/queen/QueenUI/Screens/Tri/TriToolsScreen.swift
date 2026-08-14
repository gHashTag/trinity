import Foundation
import SwiftUI

struct TriToolCommandDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let arguments: [String]
    let requiresConfirmation: Bool
}

enum TriToolCommandCatalog {
    static let commands: [TriToolCommandDefinition] = [
        command(
            "status",
            "Repository status",
            "Show the current branch and working tree.",
            "arrow.triangle.branch",
            ["status"]
        ),
        command(
            "diff",
            "Working diff",
            "Inspect uncommitted source changes.",
            "plusminus",
            ["diff"]
        ),
        command(
            "log",
            "Recent commits",
            "Read the latest repository history.",
            "clock.arrow.circlepath",
            ["log"]
        ),
        command(
            "info",
            "Runtime info",
            "Inspect the installed TRI runtime.",
            "info.circle",
            ["info"]
        ),
        command(
            "pipeline-status",
            "Pipeline status",
            "Read the Golden Chain execution state.",
            "point.3.connected.trianglepath.dotted",
            ["pipeline", "status"]
        ),
        command(
            "verify",
            "Verify project",
            "Run tests and benchmarks through TRI.",
            "checkmark.seal",
            ["verify"],
            requiresConfirmation: true
        ),
    ]

    private static func command(
        _ id: String,
        _ title: String,
        _ detail: String,
        _ systemImage: String,
        _ arguments: [String],
        requiresConfirmation: Bool = false
    ) -> TriToolCommandDefinition {
        TriToolCommandDefinition(
            id: id,
            title: title,
            detail: detail,
            systemImage: systemImage,
            arguments: arguments,
            requiresConfirmation: requiresConfirmation
        )
    }
}

enum TriToolOutputSanitizer {
    static func clean(_ output: String) -> String {
        let pattern = "\u{001B}\\[[0-?]*[ -/]*[@-~]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return output.replacingOccurrences(of: "\r", with: "")
        }
        let range = NSRange(output.startIndex..., in: output)
        return regex
            .stringByReplacingMatches(
                in: output,
                range: range,
                withTemplate: ""
            )
            .replacingOccurrences(of: "\r", with: "")
    }
}

private struct TriToolRunResult: Sendable {
    let status: Int32
    let output: String
}

/// Operational TRI workspace with a fixed command catalog and visible output.
public struct TriToolsScreen: View {
    @State private var runningCommandID: String?
    @State private var output = "Choose a command to inspect the Trinity runtime."
    @State private var pendingConfirmation: TriToolCommandDefinition?
    @State private var showsConfirmation = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ParietalSpacing.standard) {
                header
                commandGrid
                outputCard
            }
            .padding(ParietalSpacing.standard)
        }
        .background(V4Color.bgWindow)
        .confirmationDialog(
            pendingConfirmation?.title ?? "Run command",
            isPresented: $showsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Run verification") {
                guard let command = pendingConfirmation else { return }
                run(command)
                pendingConfirmation = nil
            }
            Button("Cancel", role: .cancel) {
                pendingConfirmation = nil
            }
        } message: {
            Text("Verification can take time and may create build artifacts.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: ParietalSpacing.sm) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(WernickeTypography.display48)
                .foregroundStyle(V4Color.accent)

            VStack(alignment: .leading, spacing: ParietalSpacing.xxs) {
                Text("TRI TOOLS")
                    .font(.title.weight(.bold))
                    .foregroundStyle(V4Color.accent)
                Text("Safe command console")
                    .font(.subheadline)
                    .foregroundStyle(V4Color.textSecondary)
                Label(
                    executableStatus,
                    systemImage: executableAvailable
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill"
                )
                .font(WernickeTypography.tiny.monospaced())
                .foregroundStyle(
                    executableAvailable ? V4Color.success : V4Color.error
                )
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var commandGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: ParietalSpacing.sm),
                GridItem(.flexible(), spacing: ParietalSpacing.sm),
            ],
            spacing: ParietalSpacing.sm
        ) {
            ForEach(TriToolCommandCatalog.commands) { command in
                commandButton(command)
            }
        }
    }

    private func commandButton(
        _ command: TriToolCommandDefinition
    ) -> some View {
        Button {
            if command.requiresConfirmation {
                pendingConfirmation = command
                showsConfirmation = true
            } else {
                run(command)
            }
        } label: {
            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                HStack {
                    Image(systemName: command.systemImage)
                        .foregroundStyle(V4Color.accent)
                    Spacer()
                    if runningCommandID == command.id {
                        ProgressView()
                            .controlSize(.small)
                    } else if command.requiresConfirmation {
                        Image(systemName: "exclamationmark.shield")
                            .foregroundStyle(V4Color.warning)
                    }
                }

                Text(command.title)
                    .font(WernickeTypography.captionBold)
                    .foregroundStyle(V4Color.textPrimary)
                Text(command.detail)
                    .font(WernickeTypography.tiny)
                    .foregroundStyle(V4Color.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .padding(ParietalSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(V4Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(V4Color.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(runningCommandID != nil || !executableAvailable)
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack {
                Label("OUTPUT", systemImage: "terminal")
                    .font(WernickeTypography.captionBold.monospaced())
                    .foregroundStyle(V4Color.textSecondary)
                Spacer()
                if runningCommandID != nil {
                    Text("RUNNING")
                        .font(WernickeTypography.tiny.monospaced())
                        .foregroundStyle(V4Color.warning)
                }
            }

            Divider()
                .overlay(V4Color.border)

            ScrollView(.horizontal, showsIndicators: true) {
                Text(output)
                    .font(WernickeTypography.tiny.monospaced())
                    .foregroundStyle(V4Color.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 180, alignment: .topLeading)
        }
        .padding(ParietalSpacing.sm)
        .background(V4Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(V4Color.border, lineWidth: 1)
        }
    }

    private var executableAvailable: Bool {
        FileManager.default.isExecutableFile(
            atPath: TrinityRuntimePaths.triExecutable
        )
    }

    private var executableStatus: String {
        if executableAvailable {
            return TrinityRuntimePaths.triExecutable
        }
        return "TRI executable not found"
    }

    private func run(_ command: TriToolCommandDefinition) {
        let executable = TrinityRuntimePaths.triExecutable
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            output = "TRI executable not found at \(executable)."
            return
        }

        runningCommandID = command.id
        output = "$ tri \(command.arguments.joined(separator: " "))\n"
        let root = TrinityRuntimePaths.projectRoot
        let arguments = command.arguments

        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                execute(
                    executable: executable,
                    arguments: arguments,
                    root: root
                )
            }.value

            let commandLine = "$ tri \(arguments.joined(separator: " "))"
            let body = result.output.isEmpty
                ? "Command finished without output."
                : result.output
            output = "\(commandLine)\n\n\(body)\n\nexit \(result.status)"
            runningCommandID = nil
        }
    }
}

private func execute(
    executable: String,
    arguments: [String],
    root: String
) -> TriToolRunResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.currentDirectoryURL = URL(fileURLWithPath: root)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return TriToolRunResult(
            status: process.terminationStatus,
            output: TriToolOutputSanitizer.clean(
                String(data: data, encoding: .utf8) ?? ""
            )
        )
    } catch {
        return TriToolRunResult(status: -1, output: error.localizedDescription)
    }
}
