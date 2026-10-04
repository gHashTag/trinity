# VHS tape for tri test
# Proof: 74/74 tests passing

Output recordings/tri-test.gif
Set FontSize 26
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

# Run all tests
Type "tri test"
Enter
Sleep 10s

# Show test summary
Type "tri test --summary"
Enter
Sleep 3s

# Show specific test categories
Type "tri test vsa"
Enter
Sleep 3s

Type "tri test vm"
Enter
Sleep 3s
