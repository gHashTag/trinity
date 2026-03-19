package telegram

import (
	"context"
	"database/sql"
	"os"
	"path/filepath"
	"testing"

	"github.com/gotd/td/session"
)

func TestNewPostgresSessionStorage(t *testing.T) {
	db := &sql.DB{} // Nil DB for unit test
	phone := "+1234567890"

	storage := NewPostgresSessionStorage(db, phone)

	if storage == nil {
		t.Fatal("NewPostgresSessionStorage returned nil")
	}

	if storage.phone != phone {
		t.Errorf("Expected phone %s, got %s", phone, storage.phone)
	}

	if storage.db != db {
		t.Error("Expected db to be set")
	}
}

func TestNewFileSessionStorage(t *testing.T) {
	path := "/tmp/test-session.json"

	storage := NewFileSessionStorage(path)

	if storage == nil {
		t.Fatal("NewFileSessionStorage returned nil")
	}

	if storage.path != path {
		t.Errorf("Expected path %s, got %s", path, storage.path)
	}
}

func TestFileSessionStorage_LoadSession_NotFound(t *testing.T) {
	// Use a path that doesn't exist
	path := "/tmp/nonexistent-session-12345.json"
	os.Remove(path) // Ensure it doesn't exist

	storage := NewFileSessionStorage(path)
	ctx := context.Background()

	_, err := storage.LoadSession(ctx)
	if err == nil {
		t.Error("Expected error for non-existent session file")
	}
}

func TestFileSessionStorage_StoreAndLoad(t *testing.T) {
	// Create a temporary directory for the test
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "test-session.json")

	storage := NewFileSessionStorage(path)
	ctx := context.Background()

	// Create session data
	sessionData := session.Data{
		DC:        2,
		Addr:      "149.154.167.50:443",
		AuthKey:   make([]byte, 256),
		AuthKeyID: make([]byte, 8),
	}

	// Fill with test data
	for i := range sessionData.AuthKey {
		sessionData.AuthKey[i] = byte(i)
	}
	for i := range sessionData.AuthKeyID {
		sessionData.AuthKeyID[i] = byte(i + 100)
	}

	// Store the session using gotd's format
	fileStorage := &session.FileStorage{Path: path}
	loader := session.Loader{Storage: fileStorage}
	err := loader.Save(ctx, &sessionData)
	if err != nil {
		t.Fatalf("Failed to save session: %v", err)
	}

	// Now load it back
	data, err := storage.LoadSession(ctx)
	if err != nil {
		t.Fatalf("LoadSession error: %v", err)
	}

	if len(data) == 0 {
		t.Error("Expected non-empty session data")
	}
}

// Test that PostgresSessionStorage methods work with mock-like behavior
func TestPostgresSessionStorage_Interface(t *testing.T) {
	storage := NewPostgresSessionStorage(nil, "+1234567890")

	// Verify it implements the expected interface pattern
	// (can't actually call methods without real DB, but we verify structure)
	if storage.phone == "" {
		t.Error("Phone should be set")
	}
}

// Additional file storage tests
func TestFileSessionStorage_ContextCancellation(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "test-session.json")

	storage := NewFileSessionStorage(path)

	// Create cancelled context
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	// Operations should still work (file storage doesn't check context much)
	// but we test that it doesn't panic
	_, _ = storage.LoadSession(ctx)
}
