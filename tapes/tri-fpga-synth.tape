# VHS tape for FPGA synthesis
# Shows zero DSP usage (key objection response)

Output recordings/tri-fpga-synth.gif
Set FontSize 24
Set Width 1400
Set Height 800
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms

# Run from the repository root after `zig build -Dci=true`. The hidden lines put
# the tri this checkout built first on PATH; nothing is recorded until Show.
Hide
Type "export PATH=$PWD/zig-out/bin:$PATH && clear"
Enter
Sleep 500ms
Show

# Show FPGA specs directory
Type "ls -la fpga/specs/"
Enter
Sleep 1s

# Run synthesis for a simple module
Type "/fpga-synth counter"
Enter
Sleep 8s

# Show synthesis results
Type "cat fpga/build/counter-report.txt"
Enter
Sleep 3s
