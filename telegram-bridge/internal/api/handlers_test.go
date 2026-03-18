package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/vibee/telegram-bridge/internal/config"
)

func TestHealthEndpoint(t *testing.T) {
	cfg := &config.Config{
		Port:       "8080",
		SessionDir: "/tmp/sessions",
	}

	router := NewRouter(cfg, nil)

	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response["status"] != "ok" {
		t.Errorf("Expected status 'ok', got '%v'", response["status"])
	}

	if response["service"] != "telegram-bridge" {
		t.Errorf("Expected service 'telegram-bridge', got '%v'", response["service"])
	}
}

func TestConnectEndpointMissingCredentials(t *testing.T) {
	cfg := &config.Config{
		Port:       "8080",
		SessionDir: "/tmp/sessions",
	}

	router := NewRouter(cfg, nil)

	// Test with empty body
	req := httptest.NewRequest("POST", "/api/v1/connect", bytes.NewReader([]byte("{}")))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected status 400, got %d", w.Code)
	}

	var response map[string]string
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response["error"] == "" {
		t.Error("Expected error message in response")
	}
}

func TestConnectEndpointInvalidJSON(t *testing.T) {
	cfg := &config.Config{
		Port:       "8080",
		SessionDir: "/tmp/sessions",
	}

	router := NewRouter(cfg, nil)

	req := httptest.NewRequest("POST", "/api/v1/connect", bytes.NewReader([]byte("invalid json")))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected status 400, got %d", w.Code)
	}
}

func TestAuthPhoneWithoutSession(t *testing.T) {
	cfg := &config.Config{
		Port:       "8080",
		SessionDir: "/tmp/sessions",
	}

	router := NewRouter(cfg, nil)

	body := `{"phone": "+1234567890"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/phone", bytes.NewReader([]byte(body)))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	// Should fail because no session
	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401, got %d", w.Code)
	}
}

func TestAuthCodeWithoutSession(t *testing.T) {
	cfg := &config.Config{
		Port:       "8080",
		SessionDir: "/tmp/sessions",
	}

	router := NewRouter(cfg, nil)

	body := `{"code": "12345"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/code", bytes.NewReader([]byte(body)))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401, got %d", w.Code)
	}
}

func TestGetMeWithoutSession(t *testing.T) {
	cfg := &config.Config{
		Port:       "8080",
		SessionDir: "/tmp/sessions",
	}

	router := NewRouter(cfg, nil)

	req := httptest.NewRequest("GET", "/api/v1/me", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401, got %d", w.Code)
	}
}

func TestGetDialogsWithoutSession(t *testing.T) {
	cfg := &config.Config{
		Port:       "8080",
		SessionDir: "/tmp/sessions",
	}

	router := NewRouter(cfg, nil)

	req := httptest.NewRequest("GET", "/api/v1/dialogs", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401, got %d", w.Code)
	}
}

func TestSendMessageWithoutSession(t *testing.T) {
	cfg := &config.Config{
		Port:       "8080",
		SessionDir: "/tmp/sessions",
	}

	router := NewRouter(cfg, nil)

	body := `{"chat_id": 123, "text": "hello"}`
	req := httptest.NewRequest("POST", "/api/v1/send", bytes.NewReader([]byte(body)))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401, got %d", w.Code)
	}
}

func TestMethodNotAllowed(t *testing.T) {
	cfg := &config.Config{
		Port:       "8080",
		SessionDir: "/tmp/sessions",
	}

	router := NewRouter(cfg, nil)

	// GET on POST endpoint
	req := httptest.NewRequest("GET", "/api/v1/connect", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusMethodNotAllowed {
		t.Errorf("Expected status 405, got %d", w.Code)
	}
}

func TestCORSHeaders(t *testing.T) {
	cfg := &config.Config{
		Port:           "8080",
		SessionDir:     "/tmp/sessions",
		AllowedOrigins: []string{"*"}, // Enable CORS for all origins
	}

	router := NewRouter(cfg, nil)

	req := httptest.NewRequest("OPTIONS", "/api/v1/connect", nil)
	req.Header.Set("Origin", "https://example.com")
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	// When wildcard is in allowed origins, any origin should be echoed back
	if w.Header().Get("Access-Control-Allow-Origin") != "https://example.com" {
		t.Errorf("Expected CORS Allow-Origin header to be origin, got %s", w.Header().Get("Access-Control-Allow-Origin"))
	}

	if w.Header().Get("Access-Control-Allow-Methods") == "" {
		t.Error("Expected CORS Allow-Methods header")
	}
}
