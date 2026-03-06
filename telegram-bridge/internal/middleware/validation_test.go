package middleware

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestContainsDangerousPattern_XSSScript(t *testing.T) {
	dangerous := []string{
		"<script>alert('xss')</script>",
		"<SCRIPT>alert('xss')</SCRIPT>",
		"<script src='evil.js'>",
		"javascript:alert('xss')",
		"JAVASCRIPT:alert('xss')",
	}

	for _, input := range dangerous {
		if !containsDangerousPattern(input) {
			t.Errorf("Should detect XSS pattern: %s", input)
		}
	}
}

func TestContainsDangerousPattern_EventHandlers(t *testing.T) {
	dangerous := []string{
		"onclick=alert('xss')",
		"onload =alert('xss')",
		"ONERROR = alert",
		"onmouseover='evil()'",
	}

	for _, input := range dangerous {
		if !containsDangerousPattern(input) {
			t.Errorf("Should detect event handler pattern: %s", input)
		}
	}
}

func TestContainsDangerousPattern_SQLInjection(t *testing.T) {
	dangerous := []string{
		"1 UNION SELECT * FROM users",
		"1 union select password",
		"; DROP TABLE users",
		";DROP TABLE accounts",
		"' OR '1'='1",
		"' or '1' = '1",
		"admin --",
	}

	for _, input := range dangerous {
		if !containsDangerousPattern(input) {
			t.Errorf("Should detect SQL injection pattern: %s", input)
		}
	}
}

func TestContainsDangerousPattern_Safe(t *testing.T) {
	safe := []string{
		"Hello world",
		"user@example.com",
		"+1234567890",
		"https://example.com",
		"SELECT a book",
		"Join our union",
		"Drop by the store",
	}

	for _, input := range safe {
		if containsDangerousPattern(input) {
			t.Errorf("Should not detect pattern in safe input: %s", input)
		}
	}
}

func TestValidateJSONValues_String(t *testing.T) {
	if validateJSONValues("<script>evil</script>") {
		t.Error("Should reject dangerous string")
	}
	if !validateJSONValues("safe string") {
		t.Error("Should accept safe string")
	}
}

func TestValidateJSONValues_Map(t *testing.T) {
	dangerous := map[string]interface{}{
		"safe": "hello",
		"evil": "<script>alert(1)</script>",
	}
	if validateJSONValues(dangerous) {
		t.Error("Should reject map with dangerous value")
	}

	safe := map[string]interface{}{
		"name": "John",
		"age":  30,
	}
	if !validateJSONValues(safe) {
		t.Error("Should accept safe map")
	}
}

func TestValidateJSONValues_Array(t *testing.T) {
	dangerous := []interface{}{"safe", "<script>evil</script>"}
	if validateJSONValues(dangerous) {
		t.Error("Should reject array with dangerous value")
	}

	safe := []interface{}{"hello", "world", 123}
	if !validateJSONValues(safe) {
		t.Error("Should accept safe array")
	}
}

func TestValidateJSONValues_Nested(t *testing.T) {
	dangerous := map[string]interface{}{
		"user": map[string]interface{}{
			"name": "John",
			"bio":  "javascript:alert(1)",
		},
	}
	if validateJSONValues(dangerous) {
		t.Error("Should reject nested map with dangerous value")
	}
}

func TestSanitizeString(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"hello", "hello"},
		{"<script>", "&lt;script&gt;"},
		{"hello\x00world", "helloworld"},
		{"a\"b", "a&quot;b"},
		{"a'b", "a&#39;b"},
		{"<script>alert('xss')</script>", "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"},
	}

	for _, tt := range tests {
		result := SanitizeString(tt.input)
		if result != tt.expected {
			t.Errorf("SanitizeString(%q) = %q, want %q", tt.input, result, tt.expected)
		}
	}
}

func TestValidateWalletAddress(t *testing.T) {
	valid := []string{
		"EQBynBO23ywHy_CgarY9NK9FTz0yDsG82PtcbSTQgGoXwiuA",
		"UQBynBO23ywHy_CgarY9NK9FTz0yDsG82PtcbSTQgGoXwiu_",
	}
	for _, addr := range valid {
		if !ValidateWalletAddress(addr) {
			t.Errorf("Should accept valid address: %s", addr)
		}
	}

	invalid := []string{
		"",
		"EQ",
		"0x1234567890abcdef1234567890abcdef12345678",
		"EQtooShort",
		"ABinvalidPrefix_______________________________0123",
		"EQ!nvalid_chars!______________________________0123",
	}
	for _, addr := range invalid {
		if ValidateWalletAddress(addr) {
			t.Errorf("Should reject invalid address: %s", addr)
		}
	}
}

func TestValidatePhoneNumber(t *testing.T) {
	valid := []string{
		"+1234567890",
		"+79161234567",
		"+447911123456",
		"+1234567",
		"+123456789012345",
	}
	for _, phone := range valid {
		if !ValidatePhoneNumber(phone) {
			t.Errorf("Should accept valid phone: %s", phone)
		}
	}

	invalid := []string{
		"",
		"1234567890",        // No +
		"+123456",           // Too short
		"+1234567890123456", // Too long
		"+1234-567-890",     // Invalid chars
		"+1234 567 890",     // Spaces
		"+abcdefghij",       // Letters
	}
	for _, phone := range invalid {
		if ValidatePhoneNumber(phone) {
			t.Errorf("Should reject invalid phone: %s", phone)
		}
	}
}

func TestValidateAmount(t *testing.T) {
	valid := []float64{0.01, 1, 100, 999999.99, 1000000}
	for _, amount := range valid {
		if !ValidateAmount(amount) {
			t.Errorf("Should accept valid amount: %f", amount)
		}
	}

	invalid := []float64{0, -1, -100, 1000001, 10000000}
	for _, amount := range invalid {
		if ValidateAmount(amount) {
			t.Errorf("Should reject invalid amount: %f", amount)
		}
	}
}

func TestValidationMiddleware_SafeRequest(t *testing.T) {
	handler := ValidationMiddleware(testHandler())

	body := `{"name": "John", "age": 30}`
	req := httptest.NewRequest("POST", "/api/v1/test", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected 200 for safe request, got %d", w.Code)
	}
}

func TestValidationMiddleware_DangerousBody(t *testing.T) {
	handler := ValidationMiddleware(testHandler())

	body := `{"name": "<script>alert('xss')</script>"}`
	req := httptest.NewRequest("POST", "/api/v1/test", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected 400 for dangerous body, got %d", w.Code)
	}
}

func TestValidationMiddleware_DangerousQueryParam(t *testing.T) {
	handler := ValidationMiddleware(testHandler())

	req := httptest.NewRequest("GET", "/api/v1/test?name=<script>evil</script>", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected 400 for dangerous query param, got %d", w.Code)
	}
}

func TestValidationMiddleware_InvalidJSON(t *testing.T) {
	handler := ValidationMiddleware(testHandler())

	body := `{"name": "John",}` // Invalid JSON
	req := httptest.NewRequest("POST", "/api/v1/test", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected 400 for invalid JSON, got %d", w.Code)
	}
}

func TestValidationMiddleware_LargeBody(t *testing.T) {
	handler := ValidationMiddleware(testHandler())

	// Create body larger than MaxBodySize (1MB)
	largeBody := strings.Repeat("x", MaxBodySize+1)
	req := httptest.NewRequest("POST", "/api/v1/test", bytes.NewBufferString(largeBody))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code == http.StatusOK {
		t.Error("Should reject body larger than MaxBodySize")
	}
}

func TestValidationMiddleware_GETRequest(t *testing.T) {
	handler := ValidationMiddleware(testHandler())

	req := httptest.NewRequest("GET", "/api/v1/test?query=safe", nil)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected 200 for safe GET request, got %d", w.Code)
	}
}

func TestValidationMiddleware_NonJSONPost(t *testing.T) {
	handler := ValidationMiddleware(testHandler())

	req := httptest.NewRequest("POST", "/api/v1/test", bytes.NewBufferString("plain text"))
	req.Header.Set("Content-Type", "text/plain")
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	// Should pass through without JSON validation
	if w.Code != http.StatusOK {
		t.Errorf("Expected 200 for non-JSON POST, got %d", w.Code)
	}
}
