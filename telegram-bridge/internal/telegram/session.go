package telegram

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/gotd/td/session"
)

// PostgresSessionStorage implements session.Storage using PostgreSQL
type PostgresSessionStorage struct {
	db    *sql.DB
	phone string
}

// NewPostgresSessionStorage creates a new PostgreSQL session storage
func NewPostgresSessionStorage(db *sql.DB, phone string) *PostgresSessionStorage {
	return &PostgresSessionStorage{
		db:    db,
		phone: phone,
	}
}

// LoadSession loads session from PostgreSQL
func (s *PostgresSessionStorage) LoadSession(ctx context.Context) ([]byte, error) {
	var data []byte
	err := s.db.QueryRowContext(ctx,
		"SELECT session_data FROM telegram_sessions WHERE phone = $1",
		s.phone,
	).Scan(&data)

	if err == sql.ErrNoRows {
		return nil, session.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("load session: %w", err)
	}

	return data, nil
}

// StoreSession saves session to PostgreSQL
func (s *PostgresSessionStorage) StoreSession(ctx context.Context, data []byte) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO telegram_sessions (phone, session_data)
		VALUES ($1, $2)
		ON CONFLICT (phone) DO UPDATE SET
			session_data = EXCLUDED.session_data,
			updated_at = NOW()
	`, s.phone, data)

	if err != nil {
		return fmt.Errorf("store session: %w", err)
	}

	return nil
}

// FileSessionStorage implements session.Storage using file system
type FileSessionStorage struct {
	path string
}

// NewFileSessionStorage creates a new file session storage
func NewFileSessionStorage(path string) *FileSessionStorage {
	return &FileSessionStorage{path: path}
}

// LoadSession loads session from file
func (s *FileSessionStorage) LoadSession(ctx context.Context) ([]byte, error) {
	// Use gotd built-in file storage
	storage := &session.FileStorage{Path: s.path}
	loader := session.Loader{Storage: storage}

	data, err := loader.Load(ctx)
	if err != nil {
		return nil, err
	}

	return json.Marshal(data)
}

// StoreSession saves session to file
func (s *FileSessionStorage) StoreSession(ctx context.Context, data []byte) error {
	storage := &session.FileStorage{Path: s.path}
	loader := session.Loader{Storage: storage}

	var sessionData session.Data
	if err := json.Unmarshal(data, &sessionData); err != nil {
		return err
	}

	return loader.Save(ctx, &sessionData)
}
