package config

import (
	"os"
	"testing"
)

func clearEnv() {
	os.Unsetenv("PORT")
	os.Unsetenv("SESSION_DIR")
	os.Unsetenv("TELEGRAM_APP_ID")
	os.Unsetenv("TELEGRAM_APP_HASH")
	os.Unsetenv("DATABASE_URL")
	os.Unsetenv("TELEGRAM_BOT_TOKEN")
	os.Unsetenv("TELEGRAM_BOT_WEBHOOK_URL")
	os.Unsetenv("GLEAM_URL")
	os.Unsetenv("VIBEE_API_KEY")
	os.Unsetenv("CORS_ALLOWED_ORIGINS")
}

func TestLoad_Defaults(t *testing.T) {
	clearEnv()
	defer clearEnv()

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}

	if cfg.Port != "8081" {
		t.Errorf("Expected default port 8081, got %s", cfg.Port)
	}

	if cfg.SessionDir != "./sessions" {
		t.Errorf("Expected default session dir ./sessions, got %s", cfg.SessionDir)
	}

	if cfg.GleamURL != "https://vibee-mcp.fly.dev" {
		t.Errorf("Expected default Gleam URL, got %s", cfg.GleamURL)
	}
}

func TestLoad_CustomPort(t *testing.T) {
	clearEnv()
	defer clearEnv()

	os.Setenv("PORT", "9000")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}

	if cfg.Port != "9000" {
		t.Errorf("Expected port 9000, got %s", cfg.Port)
	}
}

func TestLoad_TelegramAppID(t *testing.T) {
	clearEnv()
	defer clearEnv()

	os.Setenv("TELEGRAM_APP_ID", "12345")
	os.Setenv("TELEGRAM_APP_HASH", "abc123def456")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}

	if cfg.AppID != 12345 {
		t.Errorf("Expected AppID 12345, got %d", cfg.AppID)
	}

	if cfg.AppHash != "abc123def456" {
		t.Errorf("Expected AppHash abc123def456, got %s", cfg.AppHash)
	}
}

func TestLoad_InvalidAppID(t *testing.T) {
	clearEnv()
	defer clearEnv()

	os.Setenv("TELEGRAM_APP_ID", "invalid")

	_, err := Load()
	if err == nil {
		t.Error("Expected error for invalid TELEGRAM_APP_ID")
	}
}

func TestLoad_CORSOrigins_Empty(t *testing.T) {
	clearEnv()
	defer clearEnv()

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}

	if len(cfg.AllowedOrigins) != 0 {
		t.Errorf("Expected empty allowed origins, got %v", cfg.AllowedOrigins)
	}
}

func TestLoad_CORSOrigins_Wildcard(t *testing.T) {
	clearEnv()
	defer clearEnv()

	os.Setenv("CORS_ALLOWED_ORIGINS", "*")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}

	if len(cfg.AllowedOrigins) != 1 || cfg.AllowedOrigins[0] != "*" {
		t.Errorf("Expected wildcard origin, got %v", cfg.AllowedOrigins)
	}
}

func TestLoad_CORSOrigins_Multiple(t *testing.T) {
	clearEnv()
	defer clearEnv()

	os.Setenv("CORS_ALLOWED_ORIGINS", "https://example.com, https://test.com, https://localhost:3000")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}

	expected := []string{"https://example.com", "https://test.com", "https://localhost:3000"}
	if len(cfg.AllowedOrigins) != len(expected) {
		t.Errorf("Expected %d origins, got %d", len(expected), len(cfg.AllowedOrigins))
	}

	for i, origin := range expected {
		if cfg.AllowedOrigins[i] != origin {
			t.Errorf("Expected origin %s at index %d, got %s", origin, i, cfg.AllowedOrigins[i])
		}
	}
}

func TestLoad_DatabaseURL(t *testing.T) {
	clearEnv()
	defer clearEnv()

	os.Setenv("DATABASE_URL", "postgres://user:pass@localhost/db")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}

	if cfg.DatabaseURL != "postgres://user:pass@localhost/db" {
		t.Errorf("Expected database URL, got %s", cfg.DatabaseURL)
	}
}

func TestLoad_BotConfig(t *testing.T) {
	clearEnv()
	defer clearEnv()

	os.Setenv("TELEGRAM_BOT_TOKEN", "123456:ABC")
	os.Setenv("TELEGRAM_BOT_WEBHOOK_URL", "https://example.com/webhook")
	os.Setenv("GLEAM_URL", "https://custom-gleam.fly.dev")
	os.Setenv("VIBEE_API_KEY", "secret-key")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}

	if cfg.BotToken != "123456:ABC" {
		t.Errorf("Expected bot token, got %s", cfg.BotToken)
	}

	if cfg.BotWebhookURL != "https://example.com/webhook" {
		t.Errorf("Expected webhook URL, got %s", cfg.BotWebhookURL)
	}

	if cfg.GleamURL != "https://custom-gleam.fly.dev" {
		t.Errorf("Expected Gleam URL, got %s", cfg.GleamURL)
	}

	if cfg.ApiKey != "secret-key" {
		t.Errorf("Expected API key, got %s", cfg.ApiKey)
	}
}

func TestIsOriginAllowed_Empty(t *testing.T) {
	cfg := &Config{AllowedOrigins: []string{}}

	if cfg.IsOriginAllowed("https://example.com") {
		t.Error("Empty origins should not allow any origin")
	}
}

func TestIsOriginAllowed_Wildcard(t *testing.T) {
	cfg := &Config{AllowedOrigins: []string{"*"}}

	if !cfg.IsOriginAllowed("https://example.com") {
		t.Error("Wildcard should allow all origins")
	}

	if !cfg.IsOriginAllowed("https://any-origin.com") {
		t.Error("Wildcard should allow all origins")
	}
}

func TestIsOriginAllowed_Specific(t *testing.T) {
	cfg := &Config{AllowedOrigins: []string{"https://example.com", "https://test.com"}}

	if !cfg.IsOriginAllowed("https://example.com") {
		t.Error("Should allow listed origin")
	}

	if !cfg.IsOriginAllowed("https://test.com") {
		t.Error("Should allow listed origin")
	}

	if cfg.IsOriginAllowed("https://other.com") {
		t.Error("Should not allow unlisted origin")
	}
}

func TestIsOriginAllowed_MixedWithWildcard(t *testing.T) {
	cfg := &Config{AllowedOrigins: []string{"https://example.com", "*"}}

	// If wildcard is present, all origins should be allowed
	if !cfg.IsOriginAllowed("https://any-origin.com") {
		t.Error("Should allow any origin when wildcard is present")
	}
}

func TestGetEnv(t *testing.T) {
	os.Unsetenv("TEST_VAR")

	result := getEnv("TEST_VAR", "default")
	if result != "default" {
		t.Errorf("Expected default value, got %s", result)
	}

	os.Setenv("TEST_VAR", "custom")
	defer os.Unsetenv("TEST_VAR")

	result = getEnv("TEST_VAR", "default")
	if result != "custom" {
		t.Errorf("Expected custom value, got %s", result)
	}
}
