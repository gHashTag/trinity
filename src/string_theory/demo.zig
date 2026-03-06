const std = @import("std");
const manifold = @import("manifold.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;

    // Quintic threefold demo
    try stdout.print("=== Calabi-Yau Manifold Demo ===\n\n", .{});

    const quintic = try manifold.quinticThreefold(allocator);
    const info = try quintic.format(allocator);
    defer allocator.free(info);
    try stdout.print("{s}\n\n", .{info});

    // Hodge numbers
    try stdout.print("Hodge Numbers:\n", .{});
    try stdout.print("  h^({d},{d}) = {d} (Kähler moduli)\n", .{1, 1, quintic.hodge.h11});
    try stdout.print("  h^({d},{d}) = {d} (Complex structure moduli)\n", .{2, 1, quintic.hodge.h21});
    try stdout.print("  Total moduli: {d}\n\n", .{quintic.hodge.totalModuli()});

    // Euler characteristic
    try stdout.print("Topological Invariants:\n", .{});
    try stdout.print("  Euler characteristic χ = {d}\n", .{quintic.euler});
    try stdout.print("  χ = 2(h^({d},{d}) - h^({d},{d})) = {d}\n\n", .{
        1, 1, 2, 1, manifold.eulerChi(quintic.hodge.h11, quintic.hodge.h21)
    });

    // φ connections
    try stdout.print("Golden Ratio Connections:\n", .{});
    try stdout.print("  φ = {d:.6}\n", .{manifold.PHI});
    try stdout.print("  φ^(-1) = {d:.6}\n", .{manifold.PHI_INVERSE});
    try stdout.print("  φ² = {d:.6}\n", .{manifold.PHI_SQUARED});
    try stdout.print("  φ³ = {d:.6}\n", .{manifold.PHI_CUBED});
    try stdout.print("  φ³ × 100 = {d:.2} (compare to χ = {d})\n\n", .{
        manifold.PHI_CUBED * 100.0, quintic.euler
    });

    // φ-based moduli
    try stdout.print("φ-Based Moduli Space:\n", .{});
    const moduli = manifold.phiModuliSpace();
    try stdout.print("  Kähler moduli[0] = {d:.6} (φ^(-1))\n", .{moduli[0]});
    try stdout.print("  Complex structure[1] = {d:.6} (φ)\n", .{moduli[1]});
    try stdout.print("  Volume modulus[4] = {d:.6} (φ³)\n\n", .{moduli[4]});

    // Mirror symmetry
    const mirror = manifold.mirrorSymmetry(quintic);
    try stdout.print("Mirror Symmetry:\n", .{});
    try stdout.print("  Quintic: (h^11, h^21) = ({d}, {d}), χ = {d}\n", .{
        quintic.hodge.h11, quintic.hodge.h21, quintic.euler
    });
    try stdout.print("  Mirror:  (h^11, h^21) = ({d}, {d}), χ = {d}\n\n", .{
        mirror.hodge.h11, mirror.hodge.h21, mirror.euler
    });

    // Vacuum landscape
    try stdout.print("String Landscape:\n", .{});
    try stdout.print("  Estimated flux vacua: ~10^500\n", .{});
    try stdout.print("  Symbolic count: {d}\n", .{manifold.stringVacuumCount()});
    try stdout.print("  With flux (h11=1, h21=101, N=10): {d}\n\n", .{
        manifold.vacuumCount(1, 101, 10)
    });

    // Special geometry
    try stdout.print("Special Geometry:\n", .{});
    const volume = manifold.specialGeometryVolume(true);
    try stdout.print("  Quintic volume: V = π³/φ = {d:.6}\n", .{volume});
    try stdout.print("  (π = {d:.6}, φ = {d:.6})\n\n", .{std.math.pi, manifold.PHI});

    try stdout.print("=== Demo Complete ===\n", .{});
}
