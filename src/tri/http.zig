//! TRI HTTP Module Selector
//! φ² + 1/φ² = 3 | TRINITY

pub const HttpMethod = @import("gen_http.zig").HttpMethod;
pub const HttpStatus = @import("gen_http.zig").HttpStatus;
pub const Url = @import("gen_http.zig").Url;

pub const methodToString = @import("gen_http.zig").methodToString;
pub const statusFromCode = @import("gen_http.zig").statusFromCode;
pub const isSuccess = @import("gen_http.zig").isSuccess;
pub const isRedirect = @import("gen_http.zig").isRedirect;
pub const isClientError = @import("gen_http.zig").isClientError;
pub const isServerError = @import("gen_http.zig").isServerError;
pub const parseUrl = @import("gen_http.zig").parseUrl;
