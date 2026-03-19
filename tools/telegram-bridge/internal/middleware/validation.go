package middleware

import (
	"encoding/json"
	"io"
	"net/http"
	"regexp"
	"strings"
)

// Validation middleware sanitizes and validates input

// Common dangerous patterns to block
var dangerousPatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?i)<script[^>]*>`),           // XSS script tags
	regexp.MustCompile(`(?i)javascript:`),              // javascript: URLs
	regexp.MustCompile(`(?i)on\w+\s*=`),               // Event handlers
	regexp.MustCompile(`(?i)union\s+select`),          // SQL injection
	regexp.MustCompile(`(?i);\s*drop\s+table`),        // SQL injection
	regexp.MustCompile(`(?i)'\s*or\s+'1'\s*=\s*'1`),   // SQL injection
	regexp.MustCompile(`(?i)--\s*$`),                  // SQL comment
}

// MaxBodySize limits request body to 1MB
const MaxBodySize = 1 * 1024 * 1024

// ValidationMiddleware validates and sanitizes request input
func ValidationMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Limit body size
		r.Body = http.MaxBytesReader(w, r.Body, MaxBodySize)

		// Validate query parameters
		for key, values := range r.URL.Query() {
			for _, value := range values {
				if containsDangerousPattern(value) {
					http.Error(w, `{"error":"Invalid input detected in query parameter: `+key+`"}`, http.StatusBadRequest)
					return
				}
			}
		}

		// For POST/PUT requests with JSON body, validate content
		if r.Method == "POST" || r.Method == "PUT" || r.Method == "PATCH" {
			contentType := r.Header.Get("Content-Type")
			if strings.Contains(contentType, "application/json") {
				// Read body
				body, err := io.ReadAll(r.Body)
				if err != nil {
					http.Error(w, `{"error":"Failed to read request body"}`, http.StatusBadRequest)
					return
				}

				// Check for dangerous patterns in raw body
				bodyStr := string(body)
				if containsDangerousPattern(bodyStr) {
					http.Error(w, `{"error":"Invalid input detected in request body"}`, http.StatusBadRequest)
					return
				}

				// Validate JSON structure
				var jsonData interface{}
				if err := json.Unmarshal(body, &jsonData); err != nil {
					http.Error(w, `{"error":"Invalid JSON format"}`, http.StatusBadRequest)
					return
				}

				// Recursively validate JSON values
				if !validateJSONValues(jsonData) {
					http.Error(w, `{"error":"Invalid input detected in JSON data"}`, http.StatusBadRequest)
					return
				}

				// Restore body for downstream handlers
				r.Body = io.NopCloser(strings.NewReader(bodyStr))
			}
		}

		next.ServeHTTP(w, r)
	})
}

// containsDangerousPattern checks if string contains dangerous patterns
func containsDangerousPattern(s string) bool {
	for _, pattern := range dangerousPatterns {
		if pattern.MatchString(s) {
			return true
		}
	}
	return false
}

// validateJSONValues recursively validates all string values in JSON
func validateJSONValues(data interface{}) bool {
	switch v := data.(type) {
	case string:
		return !containsDangerousPattern(v)
	case map[string]interface{}:
		for _, value := range v {
			if !validateJSONValues(value) {
				return false
			}
		}
	case []interface{}:
		for _, item := range v {
			if !validateJSONValues(item) {
				return false
			}
		}
	}
	return true
}

// SanitizeString removes potentially dangerous characters
func SanitizeString(s string) string {
	// Remove null bytes
	s = strings.ReplaceAll(s, "\x00", "")
	// Escape HTML special characters
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, "\"", "&quot;")
	s = strings.ReplaceAll(s, "'", "&#39;")
	return s
}

// ValidateWalletAddress validates TON wallet address format
func ValidateWalletAddress(addr string) bool {
	// TON addresses start with EQ or UQ and are 48 chars base64
	if len(addr) != 48 {
		return false
	}
	if !strings.HasPrefix(addr, "EQ") && !strings.HasPrefix(addr, "UQ") {
		return false
	}
	// Check for valid base64 characters
	validChars := regexp.MustCompile(`^[A-Za-z0-9_-]+$`)
	return validChars.MatchString(addr)
}

// ValidatePhoneNumber validates phone number format
func ValidatePhoneNumber(phone string) bool {
	// Must start with + and contain only digits after
	if !strings.HasPrefix(phone, "+") {
		return false
	}
	digits := phone[1:]
	if len(digits) < 7 || len(digits) > 15 {
		return false
	}
	for _, c := range digits {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}

// ValidateAmount validates payment amount
func ValidateAmount(amount float64) bool {
	return amount > 0 && amount <= 1000000 // Max 1M
}
