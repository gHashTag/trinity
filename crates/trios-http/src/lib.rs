//! TRIOS HTTP — HTTP Client/Server FFI for Trinity Network
//!
//! This crate provides FFI bindings for TRIOS HTTP operations including
//! request/response handling, URL parsing, header management, and
//! connection pooling for the Trinity distributed network.
//!
//! ## Features
//!
//! - **HTTP Methods**: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
//! - **URL Parsing**: Scheme, host, port, path, query, fragment
//! - **Header Management**: Key-value header pairs with normalization
//! - **Request Builder**: Fluent API for constructing HTTP requests
//! - **Response Handling**: Status codes, headers, body access
//! - **Connection Pool**: Reusable connections for Trinity nodes
//!
//! ## Symbol: `🌐`

use std::os::raw::{c_char, c_int, c_long, c_ulong};

// ─── Constants ────────────────────────────────────────────────────────

/// Maximum URL length
pub const MAX_URL_LEN: usize = 2048;

/// Maximum header name length
pub const MAX_HEADER_NAME_LEN: usize = 128;

/// Maximum header value length
pub const MAX_HEADER_VALUE_LEN: usize = 1024;

/// Maximum number of headers per request
pub const MAX_HEADERS: usize = 32;

/// Maximum body size (1 MB)
pub const MAX_BODY_SIZE: usize = 1024 * 1024;

/// Default HTTP port
pub const DEFAULT_HTTP_PORT: u16 = 80;

/// Default HTTPS port
pub const DEFAULT_HTTPS_PORT: u16 = 443;

/// Default connection timeout in milliseconds
pub const DEFAULT_TIMEOUT_MS: c_long = 30_000;

/// Default max redirects
pub const DEFAULT_MAX_REDIRECTS: c_int = 10;

// ─── Enums ────────────────────────────────────────────────────────────

/// HTTP methods
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HttpMethod {
    Get = 0,
    Post = 1,
    Put = 2,
    Delete = 3,
    Patch = 4,
    Head = 5,
    Options = 6,
    Trace = 7,
}

/// HTTP status code categories
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HttpStatusCategory {
    /// 1xx — Informational
    Informational = 1,
    /// 2xx — Success
    Success = 2,
    /// 3xx — Redirection
    Redirection = 3,
    /// 4xx — Client Error
    ClientError = 4,
    /// 5xx — Server Error
    ServerError = 5,
}

/// URL scheme
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum UrlScheme {
    Http = 0,
    Https = 1,
    Ws = 2,
    Wss = 3,
}

/// Content type
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ContentType {
    /// application/json
    Json = 0,
    /// application/octet-stream
    Binary = 1,
    /// text/plain
    Text = 2,
    /// application/x-www-form-urlencoded
    FormUrlencoded = 3,
    /// multipart/form-data
    Multipart = 4,
    /// applicationprotobuf
    Protobuf = 5,
    /// Custom/unknown
    Custom = 6,
}

// ─── Structs ──────────────────────────────────────────────────────────

/// HTTP header entry
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct HttpHeader {
    /// Header name (null-terminated, lowercase)
    pub name: [c_char; MAX_HEADER_NAME_LEN],
    /// Header value (null-terminated)
    pub value: [c_char; MAX_HEADER_VALUE_LEN],
}

/// Parsed URL components
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct UrlParts {
    /// Full URL (null-terminated)
    pub url: [c_char; MAX_URL_LEN],
    /// Scheme
    pub scheme: UrlScheme,
    /// Host (null-terminated)
    pub host: [c_char; 256],
    /// Port number
    pub port: u16,
    /// Path (null-terminated)
    pub path: [c_char; 1024],
    /// Query string (null-terminated, without '?')
    pub query: [c_char; 1024],
    /// Fragment (null-terminated, without '#')
    pub fragment: [c_char; 256],
    /// Whether parsing succeeded
    pub valid: bool,
}

/// HTTP request
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct HttpRequest {
    /// HTTP method
    pub method: HttpMethod,
    /// Parsed URL
    pub url: UrlParts,
    /// Headers
    pub headers: [HttpHeader; MAX_HEADERS],
    /// Number of headers
    pub header_count: usize,
    /// Body data pointer
    pub body: *mut u8,
    /// Body length
    pub body_len: usize,
    /// Content type
    pub content_type: ContentType,
    /// Connection timeout in ms
    pub timeout_ms: c_long,
    /// Max redirects
    pub max_redirects: c_int,
    /// Whether to follow redirects
    pub follow_redirects: bool,
}

/// HTTP response
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct HttpResponse {
    /// HTTP status code (200, 404, etc.)
    pub status_code: c_int,
    /// Status category
    pub status_category: HttpStatusCategory,
    /// Headers
    pub headers: [HttpHeader; MAX_HEADERS],
    /// Number of response headers
    pub header_count: usize,
    /// Body data pointer
    pub body: *mut u8,
    /// Body length
    pub body_len: usize,
    /// Content type
    pub content_type: ContentType,
    /// Response time in milliseconds
    pub elapsed_ms: c_long,
    /// Whether the request succeeded
    pub success: bool,
}

/// Connection pool configuration
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ConnectionPoolConfig {
    /// Maximum number of connections per host
    pub max_connections_per_host: usize,
    /// Maximum total connections
    pub max_total_connections: usize,
    /// Connection idle timeout in ms
    pub idle_timeout_ms: c_long,
    /// Whether to enable TCP keepalive
    pub keepalive: bool,
    /// Keepalive interval in ms
    pub keepalive_interval_ms: c_long,
}

/// Trinity node endpoint
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct TrinityEndpoint {
    /// Node host (null-terminated)
    pub host: [c_char; 256],
    /// Node port
    pub port: u16,
    /// Node ID (null-terminated)
    pub node_id: [c_char; 64],
    /// Whether the node is healthy
    pub healthy: bool,
    /// Last response latency in ms
    pub latency_ms: c_long,
    /// Request count
    pub request_count: c_ulong,
}

// ─── URL Parsing ──────────────────────────────────────────────────────

/// Parse a URL string into components
#[no_mangle]
pub extern "C" fn trios_http_parse_url(url_str: *const c_char) -> UrlParts {
    let mut parts: UrlParts = unsafe { std::mem::zeroed() };
    parts.valid = false;

    if url_str.is_null() {
        return parts;
    }

    let url_cstr = unsafe { std::ffi::CStr::from_ptr(url_str) };
    let url_bytes = url_cstr.to_bytes();

    if url_bytes.len() >= MAX_URL_LEN {
        return parts;
    }

    // Copy full URL
    copy_str_to_buf(url_bytes, &mut parts.url);

    let url_str_inner = match std::str::from_utf8(url_bytes) {
        Ok(s) => s,
        Err(_) => return parts,
    };

    // Parse scheme
    if let Some(rest) = url_str_inner.strip_prefix("https://") {
        parts.scheme = UrlScheme::Https;
        parts.port = DEFAULT_HTTPS_PORT;
        parse_host_path(rest, &mut parts);
    } else if let Some(rest) = url_str_inner.strip_prefix("http://") {
        parts.scheme = UrlScheme::Http;
        parts.port = DEFAULT_HTTP_PORT;
        parse_host_path(rest, &mut parts);
    } else if let Some(rest) = url_str_inner.strip_prefix("wss://") {
        parts.scheme = UrlScheme::Wss;
        parts.port = 443;
        parse_host_path(rest, &mut parts);
    } else if let Some(rest) = url_str_inner.strip_prefix("ws://") {
        parts.scheme = UrlScheme::Ws;
        parts.port = 80;
        parse_host_path(rest, &mut parts);
    } else {
        return parts;
    }

    parts.valid = true;
    parts
}

/// Internal: parse host[:port]/path?query#fragment
fn parse_host_path(input: &str, parts: &mut UrlParts) {
    let (host_port, rest) = match input.find('/') {
        Some(idx) => (&input[..idx], &input[idx..]),
        None => (input, "/"),
    };

    // Split host:port
    if let Some(colon_pos) = host_port.rfind(':') {
        copy_str_to_buf(host_port[..colon_pos].as_bytes(), &mut parts.host);
        if let Ok(port) = host_port[colon_pos + 1..].parse::<u16>() {
            parts.port = port;
        }
    } else {
        copy_str_to_buf(host_port.as_bytes(), &mut parts.host);
    }

    // Split path?query#fragment
    let (path_and_query, fragment) = match rest.find('#') {
        Some(idx) => (&rest[..idx], &rest[idx + 1..]),
        None => (rest, ""),
    };
    copy_str_to_buf(fragment.as_bytes(), &mut parts.fragment);

    let (path, query) = match path_and_query.find('?') {
        Some(idx) => (&path_and_query[..idx], &path_and_query[idx + 1..]),
        None => (path_and_query, ""),
    };
    copy_str_to_buf(path.as_bytes(), &mut parts.path);
    copy_str_to_buf(query.as_bytes(), &mut parts.query);
}

/// Copy a byte slice into a fixed-size buffer, null-terminating
fn copy_str_to_buf<const N: usize>(src: &[u8], dst: &mut [c_char; N]) {
    let len = src.len().min(N - 1);
    dst[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&src[..len]) });
    dst[len] = 0;
}

// ─── Request Construction ─────────────────────────────────────────────

/// Create a new HTTP request with the given method and URL
#[no_mangle]
pub extern "C" fn trios_http_request_new(
    method: HttpMethod,
    url_str: *const c_char,
) -> HttpRequest {
    let mut req: HttpRequest = unsafe { std::mem::zeroed() };
    req.method = method;
    req.url = trios_http_parse_url(url_str);
    req.content_type = ContentType::Binary;
    req.timeout_ms = DEFAULT_TIMEOUT_MS;
    req.max_redirects = DEFAULT_MAX_REDIRECTS;
    req.follow_redirects = true;
    req
}

/// Add a header to an HTTP request
#[no_mangle]
pub extern "C" fn trios_http_request_add_header(
    req: *mut HttpRequest,
    name: *const c_char,
    value: *const c_char,
) -> bool {
    if req.is_null() || name.is_null() || value.is_null() {
        return false;
    }
    unsafe {
        if (*req).header_count >= MAX_HEADERS {
            return false;
        }
        let header = &mut (*req).headers[(*req).header_count];

        let name_cstr = std::ffi::CStr::from_ptr(name);
        let name_bytes = name_cstr.to_bytes();
        let name_len = name_bytes.len().min(MAX_HEADER_NAME_LEN - 1);
        header.name[..name_len].copy_from_slice(
            std::mem::transmute::<&[u8], &[c_char]>(&name_bytes[..name_len]),
        );
        header.name[name_len] = 0;

        let val_cstr = std::ffi::CStr::from_ptr(value);
        let val_bytes = val_cstr.to_bytes();
        let val_len = val_bytes.len().min(MAX_HEADER_VALUE_LEN - 1);
        header.value[..val_len].copy_from_slice(
            std::mem::transmute::<&[u8], &[c_char]>(&val_bytes[..val_len]),
        );
        header.value[val_len] = 0;

        (*req).header_count += 1;
        true
    }
}

/// Set request body
#[no_mangle]
pub extern "C" fn trios_http_request_set_body(
    req: *mut HttpRequest,
    body: *const u8,
    body_len: usize,
    content_type: ContentType,
) {
    if req.is_null() {
        return;
    }
    unsafe {
        (*req).body = body as *mut u8;
        (*req).body_len = body_len.min(MAX_BODY_SIZE);
        (*req).content_type = content_type;
    }
}

// ─── Response Utilities ───────────────────────────────────────────────

/// Get status code category from numeric code
#[no_mangle]
pub extern "C" fn trios_http_status_category(code: c_int) -> HttpStatusCategory {
    match code / 100 {
        1 => HttpStatusCategory::Informational,
        2 => HttpStatusCategory::Success,
        3 => HttpStatusCategory::Redirection,
        4 => HttpStatusCategory::ClientError,
        5 => HttpStatusCategory::ServerError,
        _ => HttpStatusCategory::ServerError,
    }
}

/// Check if status code indicates success (2xx)
#[no_mangle]
pub extern "C" fn trios_http_is_success(status_code: c_int) -> bool {
    status_code >= 200 && status_code < 300
}

/// Create a default connection pool config
#[no_mangle]
pub extern "C" fn trios_http_pool_config_default() -> ConnectionPoolConfig {
    ConnectionPoolConfig {
        max_connections_per_host: 4,
        max_total_connections: 16,
        idle_timeout_ms: 60_000,
        keepalive: true,
        keepalive_interval_ms: 30_000,
    }
}

/// Create a Trinity endpoint from host and port
#[no_mangle]
pub extern "C" fn trios_http_endpoint_new(
    host: *const c_char,
    port: u16,
    node_id: *const c_char,
) -> TrinityEndpoint {
    let mut ep: TrinityEndpoint = unsafe { std::mem::zeroed() };
    ep.port = port;
    ep.healthy = true;

    if !host.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(host) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(255);
        ep.host[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        ep.host[len] = 0;
    }

    if !node_id.is_null() {
        let cstr = unsafe { std::ffi::CStr::from_ptr(node_id) };
        let bytes = cstr.to_bytes();
        let len = bytes.len().min(63);
        ep.node_id[..len].copy_from_slice(unsafe { std::mem::transmute::<&[u8], &[c_char]>(&bytes[..len]) });
        ep.node_id[len] = 0;
    }

    ep
}

// ─── Unit Tests ───────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_http_url() {
        let url = trios_http_parse_url(b"http://example.com:8080/path?q=1#frag\0".as_ptr() as *const c_char);
        assert!(url.valid);
        assert_eq!(url.scheme, UrlScheme::Http);
        assert_eq!(url.port, 8080);
    }

    #[test]
    fn test_parse_https_url() {
        let url = trios_http_parse_url(b"https://api.trinity.ai/v1/nodes\0".as_ptr() as *const c_char);
        assert!(url.valid);
        assert_eq!(url.scheme, UrlScheme::Https);
        assert_eq!(url.port, DEFAULT_HTTPS_PORT);
    }

    #[test]
    fn test_parse_null_url() {
        let url = trios_http_parse_url(std::ptr::null());
        assert!(!url.valid);
    }

    #[test]
    fn test_status_category() {
        assert_eq!(trios_http_status_category(200), HttpStatusCategory::Success);
        assert_eq!(trios_http_status_category(404), HttpStatusCategory::ClientError);
        assert_eq!(trios_http_status_category(500), HttpStatusCategory::ServerError);
        assert_eq!(trios_http_status_category(301), HttpStatusCategory::Redirection);
    }

    #[test]
    fn test_is_success() {
        assert!(trios_http_is_success(200));
        assert!(trios_http_is_success(204));
        assert!(!trios_http_is_success(404));
        assert!(!trios_http_is_success(500));
    }

    #[test]
    fn test_request_new() {
        let req = trios_http_request_new(
            HttpMethod::Get,
            b"https://example.com\0".as_ptr() as *const c_char,
        );
        assert_eq!(req.method, HttpMethod::Get);
        assert!(req.url.valid);
        assert_eq!(req.timeout_ms, DEFAULT_TIMEOUT_MS);
    }

    #[test]
    fn test_add_header() {
        let mut req = trios_http_request_new(
            HttpMethod::Post,
            b"https://example.com\0".as_ptr() as *const c_char,
        );
        assert!(trios_http_request_add_header(
            &mut req,
            b"Content-Type\0".as_ptr() as *const c_char,
            b"application/json\0".as_ptr() as *const c_char,
        ));
        assert_eq!(req.header_count, 1);
    }

    #[test]
    fn test_pool_config_default() {
        let config = trios_http_pool_config_default();
        assert_eq!(config.max_connections_per_host, 4);
        assert_eq!(config.max_total_connections, 16);
        assert!(config.keepalive);
    }

    #[test]
    fn test_endpoint_new() {
        let ep = trios_http_endpoint_new(
            b"node1.trinity.ai\0".as_ptr() as *const c_char,
            443,
            b"abc123\0".as_ptr() as *const c_char,
        );
        assert_eq!(ep.port, 443);
        assert!(ep.healthy);
    }
}
