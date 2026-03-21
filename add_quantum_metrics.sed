#!/bin/bash
# Add quantum metrics (0.0) to S1, S3-S14 writeTimeline calls

# S3 MultiObj (line ~228)
sed -i '' '/s3\.timeline.*writeTimeline("S3", allocator, csv_file, s3_converged, 50\.0 \* 200\.0, 15000, 50, 0\.42, s3\.kill_threshold, 0\.60, 0\.15, 0\.15)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S4 dePIN (line ~231)
sed -i '' '/s4\.timeline.*writeTimeline("S4", allocator, csv_file, s4_converged, 100\.0 \* 300\.0, 25000, 110, 0\.50, s4\.kill_threshold, 0\.50, 0\.25, 0\.25)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S5 dePIN NoImmunity (line ~234)
sed -i '' '/s5\.timeline.*writeTimeline("S5", allocator, csv_file, s5_converged, 100\.0 \* 300\.0, 25000, 110, 0\.50, s5\.kill_threshold, 0\.50, 0\.25, 0\.25)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S6 JEPA-Heavy (line ~237)
sed -i '' '/s6\.timeline.*writeTimeline("S6", allocator, csv_file, s6_converged, 100\.0 \* 300\.0, 25000, 110, 0\.50, s6\.kill_threshold, 0\.35, 0\.35, 0\.30)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S7 High-Diversity (line ~240)
sed -i '' '/s7\.timeline.*writeTimeline("S7", allocator, csv_file, s7_converged, 150\.0 \* 200\.0, 14000, 85, 0\.27, s7\.kill_threshold, 0\.25, 0\.25, 0\.25)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S8 Low-Crash (line ~243)
sed -i '' '/s8\.timeline.*writeTimeline("S8", allocator, csv_file, s8_converged, 80\.0 \* 400\.0, 13000, 75, 0\.20, s8\.kill_threshold, 0\.70, 0\.20, 0\.10)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S9 Byzantine-Heavy (line ~246)
sed -i '' '/s9\.timeline.*writeTimeline("S9", allocator, csv_file, s9_converged, 120\.0 \* 200\.0, 16000, 85, 0\.46, s9\.kill_threshold, 0\.50, 0\.30, 0\.20)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S10 Energy-Optimal (line ~249)
sed -i '' '/s10\.timeline.*writeTimeline("S10", allocator, csv_file, s10_converged, 60\.0 \* 100\.0, 12000, 50, 0\.15, 0\.02, s10\.kill_threshold, 0\.80, 0\.0, 0\.0)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S11 Sacred-A (line ~252)
sed -i '' '/s11\.timeline.*writeTimeline("S11", allocator, csv_file, s11_converged, 120\.0 \* 200\.0, 25000, 80, 0\.40, 0\.03, s11\.kill_threshold, 0\.40, 0\.40, 0\.20)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S12 Sacred-B (line ~255)
sed -i '' '/s12\.timeline.*writeTimeline("S12", allocator, csv_file, s12_converged, 120\.0 \* 300\.0, 25000, 80, 0\.40, 0\.02, s12\.kill_threshold, 0\.35, 0\.50, 0\.15)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S13 Sacred-C (line ~258)
sed -i '' '/s13\.timeline.*writeTimeline("S13", allocator, csv_file, s13_converged, 80\.0 \* 300\.0, 15000, 90, 0\.25, s13\.kill_threshold, 0\.50, 0\.30, 0\.20)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S14 Wide (line ~261)
sed -i '' '/s14\.timeline.*writeTimeline("S14", allocator, csv_file, s14_converged, 100\.0 \* 300\.0, 18000, 100, 0\.30, s14\.kill_threshold, 0\.60, 0\.25, 0\.15)/{
    s/quantum_coherence: 0.0;\
    s/quantum_interference: 0.0;\
    s/quantum_collapse_prob: 0.0;\
}' src/cli/sim_suite.zig

# S15 Baseline-Extended already has quantum metrics (no patch needed)
# S1 Baseline already has quantum metrics (no patch needed)
EOF
