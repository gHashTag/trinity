# VHS tape for tri status
# Shows overall system health and dashboard

Output tri-status.gif
Set FontSize 26
Set Width 1200
Set Height 700
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms

# Start with clean terminal
Type "cd ~/trinity-w1"
Enter
Sleep 500ms

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
