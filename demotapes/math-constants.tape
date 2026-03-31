Output tri_math_constants.gif
Set Shell "zsh"
Set Theme "Catppuccin Macchiato"
Set FontSize 16
Set FontFamily "JetBrains Mono,Noto Sans Mono"
Set Width 1200
Set Height 675
Set Padding 30
Set Margin 30

# Dark theme (built-in dark colors)
# Use bold for titles
Type "tput bold"
Sleep 100ms

# Clear screen
Type "clear"
Enter
Sleep 200ms

# Title screen with gold color
Type "tput setaf 7 bold; tput setaf 7 2"
Sleep 100ms
Type "echo '═════════════════════════════════════════════'"
Enter
Sleep 200ms
Type "tput sgr0"
Sleep 100ms
Type "echo '  TRINITY: Sacred Mathematics from φ² + 1/φ² = 3'"
Enter
Sleep 200ms
Type "tput sgr0"
Sleep 100ms
Type "echo '═══════════════════════════════════════════════'"
Enter
Sleep 200ms

# Reset colors
Type "tput sgr0"
Sleep 100ms

# Show help header
Type "./zig-out/bin/tri math"
Enter
Sleep 4s

# Show sacred constants table
Type "./zig-out/bin/tri math sacred"
Enter
Sleep 5s

# Show cosmos comparison
Type "./zig-out/bin/tri math cosmos"
Enter
Sleep 4s

# Show JSON output
Type "./zig-out/bin/tri math physical --format=json"
Enter
Sleep 4s

# Show particle physics
Type "./zig-out/bin/tri math particles tier1"
Enter
Sleep 4s

# Final screen with summary
Type "tput setaf 7 bold"
Sleep 100ms
Type "tput sgr0"
Sleep 100ms
Type "echo '═════════════════════════════════════════════'"
Enter
Sleep 200ms
Type "tput sgr0"
Sleep 100ms
Type "echo '  CLI REPRODUCIBILITY — All results verifiable:'"
Enter
Sleep 200ms
Type "tput sgr0"
Sleep 100ms
Type "echo '  • tri math sacred          — 100 constants from φ'"
Enter
Sleep 100ms
Type "echo '  • tri math cosmos          — Cosmology vs Experiment'"
Enter
Sleep 100ms
Type "echo '  • tri math physical --json — Export for analysis'"
Enter
Sleep 100ms
Type "tput sgr0"
Sleep 100ms
Type "echo '═════════════════════════════════════════════════'"
Enter
Sleep 3s

# Pellis comparison - NEW
Type "./zig-out/bin/tri math compare --pellis"
Enter
Sleep 5s
