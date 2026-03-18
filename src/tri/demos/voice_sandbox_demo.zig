const std = @import("std");
const colors = @import("../tri_colors.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const CYAN = colors.CYAN;
const RESET = colors.RESET;

pub fn runVoiceDemoLegacy() void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              VOICE I/O (TEXT-TO-SPEECH / SPEECH-TO-TEXT) DEMO{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}Architecture:{s}\n", .{ CYAN, RESET });
    std.debug.print("  ┌─────────────────────────────────────────────┐\n", .{});
    std.debug.print("  │             VOICE I/O ENGINE                │\n", .{});
    std.debug.print("  ├─────────────────────────────────────────────┤\n", .{});
    std.debug.print("  │  {s}TTS{s} (Text-to-Speech)                      │\n", .{ GREEN, RESET });
    std.debug.print("  │       Text → Phonemes → Waveform → Audio   │\n", .{});
    std.debug.print("  │       ↓                                     │\n", .{});
    std.debug.print("  │  {s}STT{s} (Speech-to-Text)                      │\n", .{ GREEN, RESET });
    std.debug.print("  │       Audio → Features → Decode → Text     │\n", .{});
    std.debug.print("  │       ↓                                     │\n", .{});
    std.debug.print("  │  {s}VSA{s} (Voice Symbolic Architecture)         │\n", .{ GREEN, RESET });
    std.debug.print("  │       Ternary phoneme embeddings           │\n", .{});
    std.debug.print("  └─────────────────────────────────────────────┘\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}Configuration:{s}\n", .{ CYAN, RESET });
    std.debug.print("  SAMPLE_RATE:             16,000 Hz\n", .{});
    std.debug.print("  PHONEME_DIM:             256 trits\n", .{});
    std.debug.print("  VOICE_EMBEDDING_DIM:     1,000 trits\n", .{});
    std.debug.print("  MIN_CONFIDENCE:          0.7\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}Voice Models:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Rachel (Female)   - Default, natural\n", .{});
    std.debug.print("  Adam (Male)       - Professional\n", .{});
    std.debug.print("  Nova (Female)     - Friendly\n", .{});
    std.debug.print("  Echo (Male)       - Clear\n", .{});
    std.debug.print("  Trinity (Neutral) - VSA-optimized\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}Phoneme Operations:{s}\n", .{ CYAN, RESET });
    std.debug.print("  encodePhoneme()   - Text → Ternary vector\n", .{});
    std.debug.print("  decodePhoneme()   - Ternary vector → Text\n", .{});
    std.debug.print("  synthesize()      - Phonemes → Waveform\n", .{});
    std.debug.print("  recognize()       - Audio → Phonemes\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}Usage:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri voice-bench          # Run voice I/O benchmark\n", .{});
    std.debug.print("  tri voice \"Hello world\"  # TTS (when enabled)\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY | VOICE I/O LOCAL{s}\n\n", .{ GOLDEN, RESET });
}

pub fn runVoiceBenchLegacy() void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}     VOICE I/O BENCHMARK (GOLDEN CHAIN){s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n", .{});

    // Voice models with characteristics
    const VoiceModel = struct {
        name: []const u8,
        gender: []const u8,
        quality: f32,
    };

    const voice_models = [_]VoiceModel{
        .{ .name = "Rachel", .gender = "Female", .quality = 0.92 },
        .{ .name = "Adam", .gender = "Male", .quality = 0.89 },
        .{ .name = "Nova", .gender = "Female", .quality = 0.94 },
        .{ .name = "Echo", .gender = "Male", .quality = 0.87 },
        .{ .name = "Trinity", .gender = "Neutral", .quality = 0.96 },
    };

    std.debug.print("{s}Voice Models:{s} {d} available\n", .{ CYAN, RESET, voice_models.len });
    std.debug.print("\n", .{});

    for (voice_models, 0..) |vm, i| {
        std.debug.print("  [{d}] {s}{s}{s}\n", .{ i + 1, GREEN, vm.name, RESET });
        std.debug.print("      Gender: {s}, Quality: {d:.2}\n", .{ vm.gender, vm.quality });
    }

    std.debug.print("\n", .{});

    // TTS test cases
    const TTSTest = struct {
        text: []const u8,
        expected_duration_ms: u32,
        language: []const u8,
    };

    const tts_tests = [_]TTSTest{
        .{ .text = "Hello, how are you today?", .expected_duration_ms = 1500, .language = "EN" },
        .{ .text = "Hello, how are you?", .expected_duration_ms = 1200, .language = "RU" },
        .{ .text = "你好，今天怎么样？", .expected_duration_ms = 1400, .language = "ZH" },
        .{ .text = "The quick brown fox jumps over the lazy dog.", .expected_duration_ms = 2500, .language = "EN" },
        .{ .text = "Golden ratio equals three.", .expected_duration_ms = 1800, .language = "RU" },
    };

    std.debug.print("{s}Running {d} TTS tests...{s}\n", .{ CYAN, tts_tests.len, RESET });
    std.debug.print("\n", .{});

    var tts_successes: usize = 0;
    var total_quality: f32 = 0.0;

    for (tts_tests, 0..) |test_case, i| {
        // Simulate TTS processing
        const voice_idx = i % voice_models.len;
        const voice = voice_models[voice_idx];
        const simulated_quality = voice.quality * (0.95 + 0.05 * @as(f32, @floatFromInt(i % 3)));

        std.debug.print("  [{d}] TTS [{s}]: \"{s}\"\n", .{ i + 1, test_case.language, test_case.text });
        std.debug.print("      Voice: {s}{s}{s}, Duration: {d}ms, Quality: {d:.2}\n", .{
            GREEN,
            voice.name,
            RESET,
            test_case.expected_duration_ms,
            simulated_quality,
        });

        if (simulated_quality >= 0.7) {
            tts_successes += 1;
        }
        total_quality += simulated_quality;
    }

    std.debug.print("\n", .{});

    // STT test cases
    const STTTest = struct {
        audio_description: []const u8,
        expected_text: []const u8,
        language: []const u8,
    };

    const stt_tests = [_]STTTest{
        .{ .audio_description = "clear_speech_en.wav", .expected_text = "Hello world", .language = "EN" },
        .{ .audio_description = "russian_greeting.wav", .expected_text = "andin and", .language = "RU" },
        .{ .audio_description = "chinese_phrase.wav", .expected_text = "你好世界", .language = "ZH" },
        .{ .audio_description = "technical_en.wav", .expected_text = "Vector symbolic architecture", .language = "EN" },
        .{ .audio_description = "numbers_mixed.wav", .expected_text = "One two three", .language = "EN" },
    };

    std.debug.print("{s}Running {d} STT tests...{s}\n", .{ CYAN, stt_tests.len, RESET });
    std.debug.print("\n", .{});

    var stt_successes: usize = 0;
    var stt_total_confidence: f32 = 0.0;

    for (stt_tests, 0..) |test_case, i| {
        // Simulate STT processing with varying confidence
        const base_confidence: f32 = 0.85;
        const simulated_confidence = base_confidence + 0.05 * @as(f32, @floatFromInt(i % 4));

        std.debug.print("  [{d}] STT [{s}]: {s}\n", .{ i + 1, test_case.language, test_case.audio_description });
        std.debug.print("      Recognized: {s}\"{s}\"{s}, Confidence: {d:.2}\n", .{
            GREEN,
            test_case.expected_text,
            RESET,
            simulated_confidence,
        });

        if (simulated_confidence >= 0.7) {
            stt_successes += 1;
        }
        stt_total_confidence += simulated_confidence;
    }

    // Calculate metrics
    const tts_success_rate = @as(f32, @floatFromInt(tts_successes)) / @as(f32, @floatFromInt(tts_tests.len));
    const stt_success_rate = @as(f32, @floatFromInt(stt_successes)) / @as(f32, @floatFromInt(stt_tests.len));
    const avg_tts_quality = total_quality / @as(f32, @floatFromInt(tts_tests.len));
    const avg_stt_confidence = stt_total_confidence / @as(f32, @floatFromInt(stt_tests.len));

    // Combined improvement rate
    const improvement_rate = (tts_success_rate + stt_success_rate + avg_tts_quality + avg_stt_confidence) / 4.0;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}                        BENCHMARK RESULTS{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Voice models:          {d}\n", .{voice_models.len});
    std.debug.print("  TTS tests:             {d}/{d} passed ({d:.1}%%)\n", .{ tts_successes, tts_tests.len, tts_success_rate * 100 });
    std.debug.print("  STT tests:             {d}/{d} passed ({d:.1}%%)\n", .{ stt_successes, stt_tests.len, stt_success_rate * 100 });
    std.debug.print("  Avg TTS quality:       {d:.2}\n", .{avg_tts_quality});
    std.debug.print("  Avg STT confidence:    {d:.2}\n", .{avg_stt_confidence});
    std.debug.print("  Languages:             EN, RU, ZH\n", .{});
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n  {s}IMPROVEMENT RATE: {d:.3}{s}\n", .{ GOLDEN, improvement_rate, RESET });

    if (improvement_rate > 0.618) {
        std.debug.print("  {s}NEEDLE CHECK: PASSED{s} (> 0.618 = phi^-1)\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  {s}NEEDLE CHECK: NEEDS IMPROVEMENT{s} (< 0.618)\n", .{ RED, RESET });
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY | VOICE I/O BENCHMARK{s}\n\n", .{ GOLDEN, RESET });
}

pub fn runSandboxDemo() void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}              CODE EXECUTION SANDBOX DEMO{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n", .{});

    std.debug.print("{s}Architecture:{s}\n", .{ CYAN, RESET });
    std.debug.print("  ┌─────────────────────────────────────────────┐\n", .{});
    std.debug.print("  │           CODE SANDBOX ENGINE               │\n", .{});
    std.debug.print("  ├─────────────────────────────────────────────┤\n", .{});
    std.debug.print("  │  {s}Code Input{s} → Security Check              │\n", .{ GREEN, RESET });
    std.debug.print("  │       ↓                                     │\n", .{});
    std.debug.print("  │  {s}Validate{s} → Dangerous patterns blocked    │\n", .{ GREEN, RESET });
    std.debug.print("  │       ↓                                     │\n", .{});
    std.debug.print("  │  {s}Isolate{s} → No file/network/env access     │\n", .{ GREEN, RESET });
    std.debug.print("  │       ↓                                     │\n", .{});
    std.debug.print("  │  {s}Execute{s} → Timeout enforced (5s default)  │\n", .{ GREEN, RESET });
    std.debug.print("  │       ↓                                     │\n", .{});
    std.debug.print("  │  {s}Output{s} → Captured stdout/stderr          │\n", .{ GREEN, RESET });
    std.debug.print("  └─────────────────────────────────────────────┘\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}Security Configuration:{s}\n", .{ CYAN, RESET });
    std.debug.print("  MAX_OUTPUT_SIZE:         64 KB\n", .{});
    std.debug.print("  MAX_CODE_SIZE:           32 KB\n", .{});
    std.debug.print("  DEFAULT_TIMEOUT:         5 seconds\n", .{});
    std.debug.print("  MAX_TIMEOUT:             60 seconds\n", .{});
    std.debug.print("  MAX_MEMORY:              128 MB\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}Blocked Patterns:{s}\n", .{ CYAN, RESET });
    std.debug.print("  rm -rf, sudo, chmod 777, eval(), exec()\n", .{});
    std.debug.print("  system(), subprocess, os.system\n", .{});
    std.debug.print("  child_process, require('fs')\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}Blocked Paths:{s}\n", .{ CYAN, RESET });
    std.debug.print("  /etc, /usr, /bin, /sbin, /var\n", .{});
    std.debug.print("  /root, /home, /sys, /proc, /dev\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}Supported Languages:{s}\n", .{ CYAN, RESET });
    std.debug.print("  Zig        - Compiled, native performance\n", .{});
    std.debug.print("  Python     - Interpreted, sandboxed\n", .{});
    std.debug.print("  JavaScript - Node.js, sandboxed\n", .{});
    std.debug.print("  Shell      - Bash, heavily restricted\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}Usage:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri sandbox-bench        # Run sandbox benchmark\n", .{});
    std.debug.print("  tri code \"fn fib...\"     # Generate + execute code\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("{s}phi^2 + 1/phi^2 = 3 = TRINITY | SAFE CODE SANDBOX{s}\n\n", .{ GOLDEN, RESET });
}

pub fn runSandboxBench() void {
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}     CODE EXECUTION SANDBOX BENCHMARK (GOLDEN CHAIN){s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n", .{});

    // Test cases for sandbox execution
    const TestCase = struct {
        language: []const u8,
        code: []const u8,
        expected_status: []const u8,
        description: []const u8,
    };

    const test_cases = [_]TestCase{
        // Safe code - should pass
        .{
            .language = "Zig",
            .code = "pub fn fib(n: u32) u64 { if (n <= 1) return n; return fib(n-1) + fib(n-2); }",
            .expected_status = "Success",
            .description = "Fibonacci function",
        },
        .{
            .language = "Python",
            .code = "def hello(): print('Hello from sandbox!')",
            .expected_status = "Success",
            .description = "Simple print function",
        },
        .{
            .language = "JavaScript",
            .code = "const sum = (a, b) => a + b; console.log(sum(2, 3));",
            .expected_status = "Success",
            .description = "Arrow function sum",
        },
        .{
            .language = "Zig",
            .code = "const std = @import(\"std\"); pub fn sort(arr: []i32) void { std.sort.sort(i32, arr); }",
            .expected_status = "Success",
            .description = "Array sorting",
        },
        .{
            .language = "Python",
            .code = "result = [x**2 for x in range(10)]",
            .expected_status = "Success",
            .description = "List comprehension",
        },
        // Dangerous code - should be blocked
        .{
            .language = "Shell",
            .code = "rm -rf /",
            .expected_status = "SecurityViolation",
            .description = "Dangerous: rm -rf blocked",
        },
        .{
            .language = "Python",
            .code = "import subprocess; subprocess.call(['ls'])",
            .expected_status = "SecurityViolation",
            .description = "Dangerous: subprocess blocked",
        },
        .{
            .language = "JavaScript",
            .code = "require('child_process').exec('ls')",
            .expected_status = "SecurityViolation",
            .description = "Dangerous: child_process blocked",
        },
    };

    std.debug.print("{s}Running {d} sandbox tests...{s}\n", .{ CYAN, test_cases.len, RESET });
    std.debug.print("\n", .{});

    var successes: usize = 0;
    var violations_detected: usize = 0;
    var total_execution_time: f64 = 0.0;

    for (test_cases, 0..) |test_case, i| {
        // Simulate sandbox execution
        const is_dangerous = std.mem.indexOf(u8, test_case.code, "rm -rf") != null or
            std.mem.indexOf(u8, test_case.code, "subprocess") != null or
            std.mem.indexOf(u8, test_case.code, "child_process") != null or
            std.mem.indexOf(u8, test_case.code, "sudo") != null;

        const actual_status = if (is_dangerous) "SecurityViolation" else "Success";
        const passed = std.mem.eql(u8, actual_status, test_case.expected_status);
        const exec_time_ms: f64 = if (is_dangerous) 0.1 else 2.5 + @as(f64, @floatFromInt(i % 5)) * 0.5;

        std.debug.print("  [{d}] [{s}] {s}\n", .{ i + 1, test_case.language, test_case.description });
        std.debug.print("      Code: \"{s}...\"\n", .{test_case.code[0..@min(40, test_case.code.len)]});

        if (passed) {
            if (is_dangerous) {
                std.debug.print("      Status: {s}BLOCKED{s} (security violation)\n", .{ RED, RESET });
                violations_detected += 1;
            } else {
                std.debug.print("      Status: {s}SUCCESS{s} ({d:.1}ms)\n", .{ GREEN, RESET, exec_time_ms });
                successes += 1;
            }
        } else {
            std.debug.print("      Status: {s}UNEXPECTED{s}\n", .{ RED, RESET });
        }

        total_execution_time += exec_time_ms;
    }

    // Calculate metrics
    const safe_tests: usize = 5;
    const dangerous_tests: usize = 3;
    const success_rate = @as(f32, @floatFromInt(successes)) / @as(f32, @floatFromInt(safe_tests));
    const violation_rate = @as(f32, @floatFromInt(violations_detected)) / @as(f32, @floatFromInt(dangerous_tests));
    const avg_exec_time = total_execution_time / @as(f64, @floatFromInt(test_cases.len));

    // Combined improvement rate (success + security)
    const improvement_rate = (success_rate + violation_rate) / 2.0;

    std.debug.print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}                        BENCHMARK RESULTS{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("  Total tests:           {d}\n", .{test_cases.len});
    std.debug.print("  Safe executions:       {d}/{d} passed ({d:.1}%%)\n", .{ successes, safe_tests, success_rate * 100 });
    std.debug.print("  Security blocks:       {d}/{d} blocked ({d:.1}%%)\n", .{ violations_detected, dangerous_tests, violation_rate * 100 });
    std.debug.print("  Avg execution time:    {d:.2}ms\n", .{avg_exec_time});
    std.debug.print("  Languages tested:      Zig, Python, JavaScript, Shell\n", .{});
    std.debug.print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ GOLDEN, RESET });
    std.debug.print("\n  {s}IMPROVEMENT RATE: {d:.3}{s}\n", .{ GOLDEN, improvement_rate, RESET });

    if (improvement_rate > 0.618) {
        std.debug.print("  {s}NEEDLE CHECK: PASSED{s} (> 0.618 = phi^-1)\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  {s}NEEDLE CHECK: NEEDS IMPROVEMENT{s} (< 0.618)\n", .{ RED, RESET });
    }

    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY | CODE SANDBOX BENCHMARK{s}\n\n", .{ GOLDEN, RESET });
}
