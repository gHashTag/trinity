//! tri/io — Tagged IO selector

const generated = @import("gen_io.zig");
pub const IO = generated.IO;
pub const print = generated.print;
pub const readLine = generated.readLine;
pub const readFile = generated.readFile;
pub const writeFile = generated.writeFile;
