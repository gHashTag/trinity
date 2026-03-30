# VHS tape for FPGA synthesis
# Shows zero DSP usage (key objection response)

Output tri-fpga-synth.gif
Set FontSize 24
Set Width 1400
Set Height 800
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms

# Start with clean terminal
Type "cd ~/trinity-w1"
Enter
Sleep 500ms

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
