# VHS tape for tri math demo
# Demonstrates VSA (Vector Symbolic Architecture) math operations

Output recordings/tri-math-demo.gif
Set FontSize 26
Set Width 1200
Set Height 600
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms

# Run from the repository root after `zig build -Dci=true`. The hidden lines put
# the tri this checkout built first on PATH; nothing is recorded until Show.
Hide
Type "export PATH=$PWD/zig-out/bin:$PATH && clear"
Enter
Sleep 500ms
Show

# Show tri math demo
Type "tri math demo"
Enter
Sleep 5s

# Show bind operation
Type "tri math bind"
Enter
Sleep 3s

# Show similarity calculation
Type "tri math similarity"
Enter
Sleep 3s

# Show Trinity Identity proof
Type "tri math phi"
Enter
Sleep 5s
