#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Maximum URL length
 */
#define MAX_URL_LEN 2048

/**
 * Maximum header name length
 */
#define MAX_HEADER_NAME_LEN 128

/**
 * Maximum header value length
 */
#define MAX_HEADER_VALUE_LEN 1024

/**
 * Maximum number of headers per request
 */
#define MAX_HEADERS 32

/**
 * Maximum body size (1 MB)
 */
#define MAX_BODY_SIZE (1024 * 1024)

/**
 * Default HTTP port
 */
#define DEFAULT_HTTP_PORT 80

/**
 * Default HTTPS port
 */
#define DEFAULT_HTTPS_PORT 443

/**
 * Default connection timeout in milliseconds
 */
#define DEFAULT_TIMEOUT_MS 30000

/**
 * Default max redirects
 */
#define DEFAULT_MAX_REDIRECTS 10

/**
 * Content type
 */
typedef enum ContentType {
  /**
   * application/json
   */
  Json = 0,
  /**
   * application/octet-stream
   */
  Binary = 1,
  /**
   * text/plain
   */
  Text = 2,
  /**
   * application/x-www-form-urlencoded
   */
  FormUrlencoded = 3,
  /**
   * multipart/form-data
   */
  Multipart = 4,
  /**
   * applicationprotobuf
   */
  Protobuf = 5,
  /**
   * Custom/unknown
   */
  Custom = 6,
} ContentType;

/**
 * HTTP methods
 */
typedef enum HttpMethod {
  Get = 0,
  Post = 1,
  Put = 2,
  Delete = 3,
  Patch = 4,
  Head = 5,
  Options = 6,
  Trace = 7,
} HttpMethod;

/**
 * HTTP status code categories
 */
typedef enum HttpStatusCategory {
  /**
   * 1xx — Informational
   */
  Informational = 1,
  /**
   * 2xx — Success
   */
  Success = 2,
  /**
   * 3xx — Redirection
   */
  Redirection = 3,
  /**
   * 4xx — Client Error
   */
  ClientError = 4,
  /**
   * 5xx — Server Error
   */
  ServerError = 5,
} HttpStatusCategory;

/**
 * URL scheme
 */
typedef enum UrlScheme {
  Http = 0,
  Https = 1,
  Ws = 2,
  Wss = 3,
} UrlScheme;

/**
 * Parsed URL components
 */
typedef struct UrlParts {
  /**
   * Full URL (null-terminated)
   */
  char url[MAX_URL_LEN];
  /**
   * Scheme
   */
  enum UrlScheme scheme;
  /**
   * Host (null-terminated)
   */
  char host[256];
  /**
   * Port number
   */
  uint16_t port;
  /**
   * Path (null-terminated)
   */
  char path[1024];
  /**
   * Query string (null-terminated, without '?')
   */
  char query[1024];
  /**
   * Fragment (null-terminated, without '#')
   */
  char fragment[256];
  /**
   * Whether parsing succeeded
   */
  bool valid;
} UrlParts;

/**
 * HTTP header entry
 */
typedef struct HttpHeader {
  /**
   * Header name (null-terminated, lowercase)
   */
  char name[MAX_HEADER_NAME_LEN];
  /**
   * Header value (null-terminated)
   */
  char value[MAX_HEADER_VALUE_LEN];
} HttpHeader;

/**
 * HTTP request
 */
typedef struct HttpRequest {
  /**
   * HTTP method
   */
  enum HttpMethod method;
  /**
   * Parsed URL
   */
  struct UrlParts url;
  /**
   * Headers
   */
  struct HttpHeader headers[MAX_HEADERS];
  /**
   * Number of headers
   */
  uintptr_t header_count;
  /**
   * Body data pointer
   */
  uint8_t *body;
  /**
   * Body length
   */
  uintptr_t body_len;
  /**
   * Content type
   */
  enum ContentType content_type;
  /**
   * Connection timeout in ms
   */
  long timeout_ms;
  /**
   * Max redirects
   */
  int max_redirects;
  /**
   * Whether to follow redirects
   */
  bool follow_redirects;
} HttpRequest;

/**
 * Connection pool configuration
 */
typedef struct ConnectionPoolConfig {
  /**
   * Maximum number of connections per host
   */
  uintptr_t max_connections_per_host;
  /**
   * Maximum total connections
   */
  uintptr_t max_total_connections;
  /**
   * Connection idle timeout in ms
   */
  long idle_timeout_ms;
  /**
   * Whether to enable TCP keepalive
   */
  bool keepalive;
  /**
   * Keepalive interval in ms
   */
  long keepalive_interval_ms;
} ConnectionPoolConfig;

/**
 * Trinity node endpoint
 */
typedef struct TrinityEndpoint {
  /**
   * Node host (null-terminated)
   */
  char host[256];
  /**
   * Node port
   */
  uint16_t port;
  /**
   * Node ID (null-terminated)
   */
  char node_id[64];
  /**
   * Whether the node is healthy
   */
  bool healthy;
  /**
   * Last response latency in ms
   */
  long latency_ms;
  /**
   * Request count
   */
  unsigned long request_count;
} TrinityEndpoint;

/**
 * Parse a URL string into components
 */
struct UrlParts trios_http_parse_url(const char *url_str);

/**
 * Create a new HTTP request with the given method and URL
 */
struct HttpRequest trios_http_request_new(enum HttpMethod method, const char *url_str);

/**
 * Add a header to an HTTP request
 */
bool trios_http_request_add_header(struct HttpRequest *req, const char *name, const char *value);

/**
 * Set request body
 */
void trios_http_request_set_body(struct HttpRequest *req,
                                 const uint8_t *body,
                                 uintptr_t body_len,
                                 enum ContentType content_type);

/**
 * Get status code category from numeric code
 */
enum HttpStatusCategory trios_http_status_category(int code);

/**
 * Check if status code indicates success (2xx)
 */
bool trios_http_is_success(int status_code);

/**
 * Create a default connection pool config
 */
struct ConnectionPoolConfig trios_http_pool_config_default(void);

/**
 * Create a Trinity endpoint from host and port
 */
struct TrinityEndpoint trios_http_endpoint_new(const char *host,
                                               uint16_t port,
                                               const char *node_id);
