const std = @import("std");

pub fn runKoscheiCommand(allocator: std.mem.Allocator) void {
    std.debug.print(
        \\
        \\╔══════════════════════════════════════════════════════════╗
        \\║           KOSCHEI 16-STEP DEVELOPMENT CYCLE                  ║
        \\║           Mandatory Process for All Changes                  ║
        \\╚════════════════════════════════════════════════╝
        \\
        \\SPECIFICATION (Steps 1-4):
        \\  1. Create .vibee specification (SINGLE SOURCE OF TRUTH)
        \\  2. Define types (data structures)
        \\  3. Define behaviors (functions)
        \\  4. Add algorithms if needed
        \\
        \\GENERATION (Steps 5-8):
        \\  5. Run: tri gen <spec.vibee>
        \\  6. Review generated code
        \\  7. Run tests: zig build test
        \\  8. Fix any issues in SPEC (not generated code!)
        \\
        \\VALIDATION (Steps 9-12):
        \\  9. Run benchmarks
        \\  10. Write critical assessment (honest self-criticism)
        \\  11. Document achievements
        \\  12. Update technology tree
        \\
        \\DEPLOYMENT (Steps 13-16):
        \\  13. Git add & commit
        \\  14. Push to remote
        \\  15. Propose 3 tech tree options for next iteration
        \\ 16. Loop back to step 1
        \\
        \\RULES:
        \\ - NEVER edit generated code directly
        \\ - ALL changes go through .vibee specs
        \\ - One source of truth = no duplication
        \\
        \\φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
        \\
    , .{});
}
