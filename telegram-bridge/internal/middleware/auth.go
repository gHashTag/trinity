package middleware

import (
	"crypto/subtle"
	"log"
	"net/http"
	"os"
	"strings"
)

// Auth middleware provides API key authentication
// Set VIBEE_API_KEY env variable to require authentication
// SECURITY: On Fly.io (production), authentication is REQUIRED

var authWarningShown = false

// AuthMiddleware wraps an http.Handler with API key authentication
func AuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Skip auth for health checks, root, diagnostic endpoints, and Telegram webhook
		// NOTE: /api/v1/bot/webhook MUST be public - Telegram sends callbacks without auth
		// NOTE: /api/v1/bot/webhook-setup is public for diagnostics (temporary)
		// NOTE: /api/v1/bot/answer is public because it's called from vibee-mcp (internal)
		if r.URL.Path == "/health" || r.URL.Path == "/" ||
		   r.URL.Path == "/api/v1/bot/webhook-info" ||
		   r.URL.Path == "/api/v1/bot/webhook" ||
		   r.URL.Path == "/api/v1/bot/webhook-setup" ||
		   r.URL.Path == "/api/v1/bot/webhook-debug" ||
		   r.URL.Path == "/api/v1/bot/answer" {
			next.ServeHTTP(w, r)
			return
		}

		apiKey := os.Getenv("VIBEE_API_KEY")

		// Check if running on Fly.io (production)
		flyAppName := os.Getenv("FLY_APP_NAME")
		isProduction := flyAppName != ""

		// If no API key is configured
		if apiKey == "" {
			if isProduction {
				// BLOCK requests in production without API key
				http.Error(w, `{"error":"VIBEE_API_KEY not configured. Set it with: fly secrets set VIBEE_API_KEY=your-secret-key"}`, http.StatusServiceUnavailable)
				return
			}
			// Development mode - allow but warn once
			if !authWarningShown {
				log.Println("⚠️  WARNING: VIBEE_API_KEY not set - authentication disabled (dev mode only)")
				authWarningShown = true
			}
			next.ServeHTTP(w, r)
			return
		}

		// Check Authorization header
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, `{"error":"Authorization header required"}`, http.StatusUnauthorized)
			return
		}

		// Support both "Bearer <token>" and "ApiKey <token>" formats
		var providedKey string
		if strings.HasPrefix(authHeader, "Bearer ") {
			providedKey = strings.TrimPrefix(authHeader, "Bearer ")
		} else if strings.HasPrefix(authHeader, "ApiKey ") {
			providedKey = strings.TrimPrefix(authHeader, "ApiKey ")
		} else {
			http.Error(w, `{"error":"Invalid authorization format, use 'Bearer <token>' or 'ApiKey <token>'"}`, http.StatusUnauthorized)
			return
		}

		// Constant-time comparison to prevent timing attacks
		if subtle.ConstantTimeCompare([]byte(apiKey), []byte(providedKey)) != 1 {
			http.Error(w, `{"error":"Invalid API key"}`, http.StatusUnauthorized)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// AuthHandlerFunc wraps an http.HandlerFunc with API key authentication
func AuthHandlerFunc(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		AuthMiddleware(http.HandlerFunc(next)).ServeHTTP(w, r)
	}
}

// RequireSessionID middleware checks for X-Session-ID header
// This ensures requests are associated with a specific session
func RequireSessionID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sessionID := r.Header.Get("X-Session-ID")
		if sessionID == "" {
			http.Error(w, `{"error":"X-Session-ID header required"}`, http.StatusBadRequest)
			return
		}
		next.ServeHTTP(w, r)
	})
}
