# VHS tape for tri benchmark
# Key demo: benchmark performance for addressing speed objections (the 63 tok/s once quoted here is withdrawn: it was an FPGA projection, see the FPGA table in README.md)

Output recordings/tri-benchmark.gif
Set FontSize 26
Set Width 1400
Set Height 700
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms

# Run from the repository root after `zig build -Dci=true`. The hidden lines put
# the tri this checkout built first on PATH; nothing is recorded until Show.
Hide
Type "export PATH=$PWD/zig-out/bin:$PATH && clear"
Enter
Sleep 500ms
Show

# Show git status first
Type "git status"
Enter
Sleep 1s

# Run full benchmark suite
Type "tri benchmark"
Enter
Sleep 8s

# Show individual component benchmarks
Type "tri benchmark vsa"
Enter
Sleep 4s

Type "tri benchmark vm"
Enter
Sleep 4s
