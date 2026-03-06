package middleware

import "net/http"

// SecurityHeadersMiddleware adds security headers to responses
// Based on OWASP security headers recommendations
func SecurityHeadersMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Prevent clickjacking
		w.Header().Set("X-Frame-Options", "DENY")

		// Prevent MIME-type sniffing
		w.Header().Set("X-Content-Type-Options", "nosniff")

		// Enable XSS filter
		w.Header().Set("X-XSS-Protection", "1; mode=block")

		// Referrer policy
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")

		// Content Security Policy (basic - can be adjusted based on needs)
		w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss: ws:;")

		// HTTP Strict Transport Security (HSTS) - enabled for production (Fly.io uses HTTPS)
		w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")

		// Permissions Policy (previously Feature-Policy)
		w.Header().Set("Permissions-Policy", "geolocation=(), microphone=(), camera=()")

		next.ServeHTTP(w, r)
	})
}
