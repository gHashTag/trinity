package api

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"time"

	"github.com/vibee/telegram-bridge/internal/telegram"
)

// An unfinished login used to live entirely in this process: the *telegram.Client
// in r.clients, and inside it the phone and code hash. A redeploy between "enter
// your phone" and "enter the code" -- which on Railway is any push to main --
// dropped both. The user then typed a perfectly valid code into a bridge that no
// longer knew which login it belonged to, and got "Invalid or missing session"
// with no explanation, or worse, a generic failure that looked like Telegram's
// fault.
//
// What follows moves the in-flight part out of memory. The session blob itself
// already had a home in telegram_sessions; it simply was not being used, because
// handleConnect hard-coded gotd's FileStorage against an ephemeral container
// filesystem.

const pendingAuthSchema = `
CREATE TABLE IF NOT EXISTS telegram_pending_auth (
	session_id  TEXT PRIMARY KEY,
	app_id      INTEGER NOT NULL,
	app_hash    TEXT NOT NULL,
	flow        JSONB NOT NULL,
	created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS telegram_sessions (
	phone        TEXT PRIMARY KEY,
	session_data BYTEA,
	created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);`

// initAuthPersistence creates the tables the login flow needs.
//
// telegram_sessions is included because PostgresSessionStorage referenced it
// while nothing in the repository ever created it -- it was dead code aimed at
// a table that did not exist.
func (r *Router) initAuthPersistence() {
	if r.db == nil {
		log.Printf("[AUTH] No database configured: in-flight logins will NOT survive a restart")
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if _, err := r.db.ExecContext(ctx, pendingAuthSchema); err != nil {
		log.Printf("[AUTH] Failed to create auth persistence tables: %v", err)
	}
}

// savePendingAuth records the unfinished login. Best effort by design: a
// database hiccup must not fail a login that is otherwise proceeding, so it is
// logged rather than returned.
func (r *Router) savePendingAuth(sessionID string, client *telegram.Client) {
	if r.db == nil || sessionID == "" {
		return
	}

	appID, appHash := client.Credentials()
	flow, err := json.Marshal(client.ExportPendingAuth())
	if err != nil {
		log.Printf("[AUTH] marshal pending auth for %s: %v", sessionID, err)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err = r.db.ExecContext(ctx, `
		INSERT INTO telegram_pending_auth (session_id, app_id, app_hash, flow)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (session_id) DO UPDATE SET
			app_id = EXCLUDED.app_id,
			app_hash = EXCLUDED.app_hash,
			flow = EXCLUDED.flow,
			updated_at = NOW()
	`, sessionID, appID, appHash, flow)
	if err != nil {
		log.Printf("[AUTH] save pending auth for %s: %v", sessionID, err)
	}
}

// clearPendingAuth drops the record once the login has completed.
func (r *Router) clearPendingAuth(sessionID string) error {
	if r.db == nil || sessionID == "" {
		return nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := r.db.ExecContext(ctx,
		"DELETE FROM telegram_pending_auth WHERE session_id = $1", sessionID)
	return err
}

// restoreClient rebuilds a client for a session this process has never seen,
// which after a restart is every session.
//
// It returns nil when there is nothing to restore -- an unknown session id is
// still an unknown session id, and this must not manufacture one.
func (r *Router) restoreClient(sessionID string) *telegram.Client {
	if r.db == nil || sessionID == "" {
		return nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var appID int
	var appHash string
	var flowJSON []byte
	err := r.db.QueryRowContext(ctx, `
		SELECT app_id, app_hash, flow FROM telegram_pending_auth WHERE session_id = $1
	`, sessionID).Scan(&appID, &appHash, &flowJSON)
	if err == sql.ErrNoRows {
		return nil
	}
	if err != nil {
		log.Printf("[AUTH] restore pending auth for %s: %v", sessionID, err)
		return nil
	}

	var pending telegram.PendingAuth
	if err := json.Unmarshal(flowJSON, &pending); err != nil {
		log.Printf("[AUTH] unmarshal pending auth for %s: %v", sessionID, err)
		return nil
	}

	storage := telegram.NewPostgresSessionStorage(r.db, sessionID)
	client, err := telegram.NewClient(appID, appHash, storage)
	if err != nil {
		log.Printf("[AUTH] rebuild client for %s: %v", sessionID, err)
		return nil
	}
	if err := client.Connect(context.Background()); err != nil {
		log.Printf("[AUTH] reconnect restored client for %s: %v", sessionID, err)
		return nil
	}
	client.RestorePendingAuth(pending)

	r.mu.Lock()
	// Another request may have restored the same session while this one was
	// connecting; the first one to register wins and this copy is discarded.
	if existing, ok := r.clients[sessionID]; ok {
		r.mu.Unlock()
		return existing
	}
	r.clients[sessionID] = client
	r.mu.Unlock()

	go r.forwardUpdates(sessionID, client)

	log.Printf("[AUTH] Restored in-flight login for session %s after restart (phone=%s, delivery=%s)",
		sessionID, pending.Phone, pending.CodeType)
	return client
}
