//! TRI Net Module Selector
pub const IpAddress = @import("gen_net.zig").IpAddress;
pub const SocketAddr = @import("gen_net.zig").SocketAddr;
pub const parseIp = @import("gen_net.zig").parseIp;
pub const isLocalhost = @import("gen_net.zig").isLocalhost;
pub const isValidPort = @import("gen_net.zig").isValidPort;
