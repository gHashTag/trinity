//! TRI JSON Module Selector
//! φ² + 1/φ² = 3 | TRINITY

pub const JsonType = @import("gen_json.zig").JsonType;
pub const JsonValue = @import("gen_json.zig").JsonValue;
pub const JsonEntry = @import("gen_json.zig").JsonEntry;

pub const nullValue = @import("gen_json.zig").nullValue;
pub const boolValue = @import("gen_json.zig").boolValue;
pub const numberValue = @import("gen_json.zig").numberValue;
pub const stringValue = @import("gen_json.zig").stringValue;
pub const arrayValue = @import("gen_json.zig").arrayValue;
pub const objectValue = @import("gen_json.zig").objectValue;
pub const get = @import("gen_json.zig").get;
pub const getAt = @import("gen_json.zig").getAt;
pub const asString = @import("gen_json.zig").asString;
pub const asNumber = @import("gen_json.zig").asNumber;
pub const asBool = @import("gen_json.zig").asBool;
pub const isNull = @import("gen_json.zig").isNull;
pub const arrayLen = @import("gen_json.zig").arrayLen;
pub const objectSize = @import("gen_json.zig").objectSize;
