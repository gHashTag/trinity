package middleware

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

// testHandler is a simple handler that writes "OK" response
func testHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	}
}

func TestAuthMiddleware_SkipsHealthEndpoint(t *testing.T) {
	// Reset warning state
	authWarningShown = false
	os.Unsetenv("VIBEE_API_KEY")
	os.Unsetenv("FLY_APP_NAME")

	handler := AuthMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200 for /health, got %d", w.Code)
	}
}

func TestAuthMiddleware_SkipsRootEndpoint(t *testing.T) {
	os.Unsetenv("VIBEE_API_KEY")
	os.Unsetenv("FLY_APP_NAME")

	handler := AuthMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200 for /, got %d", w.Code)
	}
}

func TestAuthMiddleware_SkipsBotWebhook(t *testing.T) {
	os.Unsetenv("VIBEE_API_KEY")
	os.Unsetenv("FLY_APP_NAME")

	handler := AuthMiddleware(testHandler())

	endpoints := []string{
		"/api/v1/bot/webhook",
		"/api/v1/bot/webhook-info",
		"/api/v1/bot/webhook-setup",
		"/api/v1/bot/webhook-debug",
		"/api/v1/bot/answer",
	}

	for _, endpoint := range endpoints {
		req := httptest.NewRequest("POST", endpoint, nil)
		w := httptest.NewRecorder()

		handler.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("Expected status 200 for %s, got %d", endpoint, w.Code)
		}
	}
}

func TestAuthMiddleware_NoAPIKeyDevMode(t *testing.T) {
	authWarningShown = false
	os.Unsetenv("VIBEE_API_KEY")
	os.Unsetenv("FLY_APP_NAME")

	handler := AuthMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	// Should allow request in dev mode without API key
	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200 in dev mode, got %d", w.Code)
	}
}

func TestAuthMiddleware_NoAPIKeyProdMode(t *testing.T) {
	os.Unsetenv("VIBEE_API_KEY")
	os.Setenv("FLY_APP_NAME", "vibee-telegram-bridge")
	defer os.Unsetenv("FLY_APP_NAME")

	handler := AuthMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	// Should block request in production without API key configured
	if w.Code != http.StatusServiceUnavailable {
		t.Errorf("Expected status 503 in prod mode without API key, got %d", w.Code)
	}
}

func TestAuthMiddleware_MissingAuthHeader(t *testing.T) {
	os.Setenv("VIBEE_API_KEY", "test-secret-key")
	os.Unsetenv("FLY_APP_NAME")
	defer os.Unsetenv("VIBEE_API_KEY")

	handler := AuthMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401, got %d", w.Code)
	}
}

func TestAuthMiddleware_InvalidAuthFormat(t *testing.T) {
	os.Setenv("VIBEE_API_KEY", "test-secret-key")
	os.Unsetenv("FLY_APP_NAME")
	defer os.Unsetenv("VIBEE_API_KEY")

	handler := AuthMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	req.Header.Set("Authorization", "Basic dXNlcjpwYXNz") // Basic auth format
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401 for invalid format, got %d", w.Code)
	}
}

func TestAuthMiddleware_ValidBearerToken(t *testing.T) {
	os.Setenv("VIBEE_API_KEY", "test-secret-key")
	os.Unsetenv("FLY_APP_NAME")
	defer os.Unsetenv("VIBEE_API_KEY")

	handler := AuthMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	req.Header.Set("Authorization", "Bearer test-secret-key")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}
}

func TestAuthMiddleware_ValidApiKeyToken(t *testing.T) {
	os.Setenv("VIBEE_API_KEY", "test-secret-key")
	os.Unsetenv("FLY_APP_NAME")
	defer os.Unsetenv("VIBEE_API_KEY")

	handler := AuthMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	req.Header.Set("Authorization", "ApiKey test-secret-key")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}
}

func TestAuthMiddleware_InvalidToken(t *testing.T) {
	os.Setenv("VIBEE_API_KEY", "test-secret-key")
	os.Unsetenv("FLY_APP_NAME")
	defer os.Unsetenv("VIBEE_API_KEY")

	handler := AuthMiddleware(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	req.Header.Set("Authorization", "Bearer wrong-key")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401, got %d", w.Code)
	}
}

func TestAuthHandlerFunc(t *testing.T) {
	os.Setenv("VIBEE_API_KEY", "test-secret-key")
	os.Unsetenv("FLY_APP_NAME")
	defer os.Unsetenv("VIBEE_API_KEY")

	handler := AuthHandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	// Test without auth
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()
	handler(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected 401 without auth, got %d", w.Code)
	}

	// Test with auth
	req = httptest.NewRequest("GET", "/api/v1/test", nil)
	req.Header.Set("Authorization", "Bearer test-secret-key")
	w = httptest.NewRecorder()
	handler(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("Expected 200 with auth, got %d", w.Code)
	}
}

func TestRequireSessionID_Missing(t *testing.T) {
	handler := RequireSessionID(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected status 400, got %d", w.Code)
	}
}

func TestRequireSessionID_Present(t *testing.T) {
	handler := RequireSessionID(testHandler())
	req := httptest.NewRequest("GET", "/api/v1/test", nil)
	req.Header.Set("X-Session-ID", "session-123")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}
}
