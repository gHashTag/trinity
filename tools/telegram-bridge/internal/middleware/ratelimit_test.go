package middleware

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"
)

func TestNewRateLimiter_Default(t *testing.T) {
	os.Unsetenv("VIBEE_RATE_LIMIT")
	rl := NewRateLimiter()

	if rl.rateLimit != 60 {
		t.Errorf("Expected default rate limit 60, got %d", rl.rateLimit)
	}
}

func TestNewRateLimiter_Custom(t *testing.T) {
	os.Setenv("VIBEE_RATE_LIMIT", "100")
	defer os.Unsetenv("VIBEE_RATE_LIMIT")

	rl := NewRateLimiter()

	if rl.rateLimit != 100 {
		t.Errorf("Expected rate limit 100, got %d", rl.rateLimit)
	}
}

func TestNewRateLimiter_InvalidEnv(t *testing.T) {
	os.Setenv("VIBEE_RATE_LIMIT", "invalid")
	defer os.Unsetenv("VIBEE_RATE_LIMIT")

	rl := NewRateLimiter()

	// Should fall back to default
	if rl.rateLimit != 60 {
		t.Errorf("Expected default rate limit 60, got %d", rl.rateLimit)
	}
}

func TestRateLimiter_Allow(t *testing.T) {
	os.Unsetenv("VIBEE_RATE_LIMIT")
	rl := &RateLimiter{
		tokens:     make(map[string]int),
		lastRefill: make(map[string]time.Time),
		rateLimit:  5,
		interval:   time.Minute,
	}

	key := "test-ip"

	// First 5 requests should be allowed
	for i := 0; i < 5; i++ {
		if !rl.Allow(key) {
			t.Errorf("Request %d should be allowed", i+1)
		}
	}

	// 6th request should be denied
	if rl.Allow(key) {
		t.Error("Request 6 should be denied")
	}
}

func TestRateLimiter_DifferentKeys(t *testing.T) {
	rl := &RateLimiter{
		tokens:     make(map[string]int),
		lastRefill: make(map[string]time.Time),
		rateLimit:  2,
		interval:   time.Minute,
	}

	// Each key should have its own limit
	if !rl.Allow("ip1") {
		t.Error("ip1 request 1 should be allowed")
	}
	if !rl.Allow("ip1") {
		t.Error("ip1 request 2 should be allowed")
	}
	if rl.Allow("ip1") {
		t.Error("ip1 request 3 should be denied")
	}

	// ip2 should still have its limit
	if !rl.Allow("ip2") {
		t.Error("ip2 request 1 should be allowed")
	}
	if !rl.Allow("ip2") {
		t.Error("ip2 request 2 should be allowed")
	}
}

func TestRateLimiter_Refill(t *testing.T) {
	rl := &RateLimiter{
		tokens:     make(map[string]int),
		lastRefill: make(map[string]time.Time),
		rateLimit:  2,
		interval:   100 * time.Millisecond, // Short interval for testing
	}

	key := "test-ip"

	// Use all tokens
	rl.Allow(key)
	rl.Allow(key)
	if rl.Allow(key) {
		t.Error("Should be rate limited")
	}

	// Wait for refill
	time.Sleep(150 * time.Millisecond)

	// Should be allowed again
	if !rl.Allow(key) {
		t.Error("Should be allowed after refill")
	}
}

func TestRateLimitMiddleware_SkipsHealth(t *testing.T) {
	rl := &RateLimiter{
		tokens:     make(map[string]int),
		lastRefill: make(map[string]time.Time),
		rateLimit:  1,
		interval:   time.Minute,
	}

	handler := RateLimitMiddleware(rl)(testHandler())

	// First request uses the token
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	// Second request to /health should still work
	req = httptest.NewRequest("GET", "/health", nil)
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Health endpoint should bypass rate limit, got %d", w.Code)
	}
}

func TestRateLimitMiddleware_ReturnsRetryAfter(t *testing.T) {
	rl := &RateLimiter{
		tokens:     make(map[string]int),
		lastRefill: make(map[string]time.Time),
		rateLimit:  1,
		interval:   time.Minute,
	}

	handler := RateLimitMiddleware(rl)(testHandler())

	// First request uses the token
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	req.RemoteAddr = "192.168.1.1:12345"
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	// Second request should be rate limited
	req = httptest.NewRequest("GET", "/api/v1/test", nil)
	req.RemoteAddr = "192.168.1.1:12345"
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Errorf("Expected 429, got %d", w.Code)
	}

	if w.Header().Get("Retry-After") != "60" {
		t.Errorf("Expected Retry-After header")
	}
}

func TestRateLimitMiddleware_UsesXForwardedFor(t *testing.T) {
	rl := &RateLimiter{
		tokens:     make(map[string]int),
		lastRefill: make(map[string]time.Time),
		rateLimit:  1,
		interval:   time.Minute,
	}

	handler := RateLimitMiddleware(rl)(testHandler())

	// First request with X-Forwarded-For
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	req.Header.Set("X-Forwarded-For", "10.0.0.1")
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("First request should be allowed, got %d", w.Code)
	}

	// Second request with same X-Forwarded-For should be limited
	req = httptest.NewRequest("GET", "/api/v1/test", nil)
	req.Header.Set("X-Forwarded-For", "10.0.0.1")
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Errorf("Second request should be limited, got %d", w.Code)
	}

	// Request with different X-Forwarded-For should be allowed
	req = httptest.NewRequest("GET", "/api/v1/test", nil)
	req.Header.Set("X-Forwarded-For", "10.0.0.2")
	w = httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Request from different IP should be allowed, got %d", w.Code)
	}
}
