//! Корень модуля DePIN.
//!
//! network.zig, bootstrap.zig и persistence.zig ссылаются друг на друга,
//! поэтому объявлять каждый отдельным модулем нельзя — Zig сообщает
//! «file exists in modules ... and ...». Один модуль-корень с реэкспортами
//! снимает проблему: все файлы попадают ровно в один модуль.

pub const network = @import("network.zig");
pub const bootstrap = @import("bootstrap.zig");
pub const persistence = @import("persistence.zig");
pub const metrics = @import("metrics.zig");
