# ═══════════════════════════════════════════════════════════════════════════════
# TRI CLI — Homebrew Formula
# Unified Trinity Command Line Interface
# φ² + 1/φ² = 3 = TRINITY
# ═══════════════════════════════════════════════════════════════════════════════

class Tri < Formula
  desc "Unified Trinity CLI — Chat, Code, Vision, Voice, Tools, Autonomous Agents"
  homepage "https://github.com/gHashTag/trinity"
  url "https://github.com/gHashTag/trinity.git", branch: "main"
  version "1.0.0"
  license "MIT"

  depends_on "zig" => ["0.15", :build]

  # Bottles for macOS (optional - prebuilt binaries)
  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/gHashTag/trinity/releases/download/v1.0.0/tri-aarch64-macos.tar.gz"
      sha256 "tri-aarch64-macos-sha256-placeholder"  # TODO: Update on release
    else
      url "https://github.com/gHashTag/trinity/releases/download/v1.0.0/tri-x86_64-macos.tar.gz"
      sha256 "tri-x86_64-macos-sha256-placeholder"  # TODO: Update on release
    end
  end

  def install
    if build.head?
      # Build from source
      system "zig", "build", "tri"
      bin.install "zig-out/bin/tri" => "tri"
      bin.install "zig-out/bin/vibee" => "vibee"
    else
      # Install from bottle
      bin.install "tri" => "tri"
      bin.install "vibee" => "vibee"
    end

    # Install shell completions
    bash_completion.install "completions/tri.bash" => "tri" if build.head?
    zsh_completion.install "completions/tri.zsh" => "_tri" if build.head?
    fish_completion.install "completions/tri.fish" => "tri.fish" if build.head?
  end

  def post_install
    # Initialize TRI config directory
    system "#{bin}/tri", "init" if File.exist?("#{bin}/tri")
  end

  test do
    # Test basic commands
    assert_match "TRI", shell_output("#{bin}/tri version")
    assert_match "φ", shell_output("#{bin}/tri constants")
  end

  service do
    run [bin/"tri", "daemon", "start"]
    environment_variables PATH: "#{HOMEBREW_PREFIX}/bin:#{ENV['PATH']}"
    log_path var/"log/tri.log"
    error_log_path var/"log/tri-error.log"
  end
end
