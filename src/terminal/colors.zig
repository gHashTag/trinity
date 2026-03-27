// ANSI Colors Selector — Self-hosted from .tri spec
// φ² + 1/φ² = 3 | TRINITY

const gen = @import("gen_colors.zig");

// Re-export all color constants
pub const GREEN = gen.GREEN;
pub const GOLDEN = gen.GOLDEN;
pub const WHITE = gen.WHITE;
pub const GRAY = gen.GRAY;
pub const RED = gen.RED;
pub const CYAN = gen.CYAN;
pub const PURPLE = gen.PURPLE;
pub const YELLOW = gen.YELLOW;
pub const RESET = gen.RESET;

// Re-export all print functions
pub const printGold = gen.printGold;
pub const printGreen = gen.printGreen;
pub const printWhite = gen.printWhite;
pub const printYellow = gen.printYellow;
pub const printCyan = gen.printCyan;
pub const printRed = gen.printRed;
pub const printPurple = gen.printPurple;
pub const printGray = gen.printGray;
