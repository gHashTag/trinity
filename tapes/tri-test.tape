# VHS tape for tri test
# Proof: 74/74 tests passing

Output tri-test.gif
Set FontSize 26
Set Width 1400
Set Height 800
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms

# Start with clean terminal
Type "cd ~/trinity-w1"
Enter
Sleep 500ms

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
