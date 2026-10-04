# VHS tape for tri status
# Shows overall system health and dashboard

Output recordings/tri-status.gif
Set FontSize 26
Set Width 1200
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

# Show overall status
Type "tri status"
Enter
Sleep 3s

# Show git status
Type "tri git status"
Enter
Sleep 2s

# Show agent status
Type "tri faculty"
Enter
Sleep 3s
