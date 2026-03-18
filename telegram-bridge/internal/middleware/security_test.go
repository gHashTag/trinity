package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestSecurityHeadersMiddleware_XFrameOptions(t *testing.T) {
	handler := SecurityHeadersMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Header().Get("X-Frame-Options") != "DENY" {
		t.Errorf("Expected X-Frame-Options: DENY, got %s", w.Header().Get("X-Frame-Options"))
	}
}

func TestSecurityHeadersMiddleware_XContentTypeOptions(t *testing.T) {
	handler := SecurityHeadersMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Header().Get("X-Content-Type-Options") != "nosniff" {
		t.Errorf("Expected X-Content-Type-Options: nosniff, got %s", w.Header().Get("X-Content-Type-Options"))
	}
}

func TestSecurityHeadersMiddleware_XSSProtection(t *testing.T) {
	handler := SecurityHeadersMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Header().Get("X-XSS-Protection") != "1; mode=block" {
		t.Errorf("Expected X-XSS-Protection: 1; mode=block, got %s", w.Header().Get("X-XSS-Protection"))
	}
}

func TestSecurityHeadersMiddleware_ReferrerPolicy(t *testing.T) {
	handler := SecurityHeadersMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Header().Get("Referrer-Policy") != "strict-origin-when-cross-origin" {
		t.Errorf("Expected Referrer-Policy: strict-origin-when-cross-origin, got %s", w.Header().Get("Referrer-Policy"))
	}
}

func TestSecurityHeadersMiddleware_CSP(t *testing.T) {
	handler := SecurityHeadersMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	csp := w.Header().Get("Content-Security-Policy")
	if csp == "" {
		t.Error("Expected Content-Security-Policy header")
	}
	if csp[:12] != "default-src " {
		t.Errorf("CSP should start with default-src, got %s", csp[:12])
	}
}

func TestSecurityHeadersMiddleware_HSTS(t *testing.T) {
	handler := SecurityHeadersMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	hsts := w.Header().Get("Strict-Transport-Security")
	if hsts == "" {
		t.Error("Expected Strict-Transport-Security header")
	}
	if hsts != "max-age=31536000; includeSubDomains" {
		t.Errorf("Expected max-age=31536000; includeSubDomains, got %s", hsts)
	}
}

func TestSecurityHeadersMiddleware_PermissionsPolicy(t *testing.T) {
	handler := SecurityHeadersMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	pp := w.Header().Get("Permissions-Policy")
	if pp == "" {
		t.Error("Expected Permissions-Policy header")
	}
	if pp != "geolocation=(), microphone=(), camera=()" {
		t.Errorf("Expected geolocation=(), microphone=(), camera=(), got %s", pp)
	}
}

func TestSecurityHeadersMiddleware_PassesRequest(t *testing.T) {
	called := false
	handler := SecurityHeadersMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if !called {
		t.Error("Security middleware should pass request to next handler")
	}
	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}
}

func TestSecurityHeadersMiddleware_AllHeaders(t *testing.T) {
	handler := SecurityHeadersMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	expectedHeaders := []string{
		"X-Frame-Options",
		"X-Content-Type-Options",
		"X-XSS-Protection",
		"Referrer-Policy",
		"Content-Security-Policy",
		"Strict-Transport-Security",
		"Permissions-Policy",
	}

	for _, header := range expectedHeaders {
		if w.Header().Get(header) == "" {
			t.Errorf("Missing security header: %s", header)
		}
	}
}
