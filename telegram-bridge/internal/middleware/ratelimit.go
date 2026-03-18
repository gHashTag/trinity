package middleware

import (
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"
)

// RateLimiter implements a simple token bucket rate limiter
type RateLimiter struct {
	mu           sync.Mutex
	tokens       map[string]int
	lastRefill   map[string]time.Time
	rateLimit    int           // requests per interval
	interval     time.Duration // refill interval
}

// NewRateLimiter creates a new rate limiter
// Default: 60 requests per minute
func NewRateLimiter() *RateLimiter {
	// Read rate limit from environment or use default
	rateLimit := 60
	if envLimit := os.Getenv("VIBEE_RATE_LIMIT"); envLimit != "" {
		if parsed, err := strconv.Atoi(envLimit); err == nil && parsed > 0 {
			rateLimit = parsed
		}
	}

	rl := &RateLimiter{
		tokens:     make(map[string]int),
		lastRefill: make(map[string]time.Time),
		rateLimit:  rateLimit,
		interval:   time.Minute,
	}

	// Start cleanup goroutine
	go rl.cleanup()

	return rl
}

// Allow checks if a request from the given key should be allowed
func (rl *RateLimiter) Allow(key string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()

	// Refill tokens if interval has passed
	if last, ok := rl.lastRefill[key]; !ok || now.Sub(last) >= rl.interval {
		rl.tokens[key] = rl.rateLimit
		rl.lastRefill[key] = now
	}

	// Check if we have tokens
	if rl.tokens[key] > 0 {
		rl.tokens[key]--
		return true
	}

	return false
}

// cleanup removes stale entries every 5 minutes
func (rl *RateLimiter) cleanup() {
	ticker := time.NewTicker(5 * time.Minute)
	for range ticker.C {
		rl.mu.Lock()
		now := time.Now()
		for key, last := range rl.lastRefill {
			if now.Sub(last) > 10*time.Minute {
				delete(rl.tokens, key)
				delete(rl.lastRefill, key)
			}
		}
		rl.mu.Unlock()
	}
}

// RateLimitMiddleware creates an HTTP middleware for rate limiting
func RateLimitMiddleware(rl *RateLimiter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Skip rate limiting for health checks
			if r.URL.Path == "/health" {
				next.ServeHTTP(w, r)
				return
			}

			// Use IP address as the rate limit key
			// In production with a reverse proxy, use X-Forwarded-For
			key := r.RemoteAddr
			if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
				key = xff
			}

			if !rl.Allow(key) {
				w.Header().Set("Retry-After", "60")
				http.Error(w, `{"error":"Rate limit exceeded, try again later"}`, http.StatusTooManyRequests)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
